#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/kernel-module-boot","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

module = p["module"]
expected = str(p["numdummies"])
load_file = p["load_file"]
options_file = p["options_file"]

lsmod_line = next((line for line in run("lsmod").splitlines() if line.split() and line.split()[0] == module), "")
loaded = bool(lsmod_line) and os.path.isdir(f"/sys/module/{module}")
c1 = criterion("module_loaded", loaded, 2, "kernel module is currently loaded", lsmod_line or f"{module} not in lsmod")

param_path = f"/sys/module/{module}/parameters/numdummies"
actual = open(param_path).read().strip() if os.path.isfile(param_path) else ""
c2 = criterion("option_active", actual == expected, 3, "module option numdummies has the requested value",
               f"numdummies={actual}" if actual else "parameter not readable")

load_lines = []
if os.path.isfile(load_file):
    load_lines = [line.split("#", 1)[0].strip() for line in open(load_file)]
c3 = criterion("load_at_boot", module in load_lines, 3, "module is configured to load at boot",
               load_file if module in load_lines else f"{load_file}: no '{module}' line")

options_ok = False
evidence4 = f"{options_file} missing"
if os.path.isfile(options_file):
    evidence4 = f"{options_file}: no matching options line"
    for raw in open(options_file):
        tokens = raw.split("#", 1)[0].split()
        if len(tokens) >= 3 and tokens[0] == "options" and tokens[1] == module and f"numdummies={expected}" in tokens[2:]:
            options_ok = True
            evidence4 = " ".join(tokens)
            break
c4 = criterion("option_persistent", options_ok, 2, "module option is persisted for boot", evidence4)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
