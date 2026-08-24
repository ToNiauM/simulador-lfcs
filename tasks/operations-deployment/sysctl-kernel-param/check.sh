#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/sysctl-kernel-param","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

conf = p["conf_file"]
expected = {"vm.swappiness": str(p["swappiness"]), "kernel.pid_max": str(p["pid_max"])}

active_swap = run("sysctl", "-n", "vm.swappiness")
c1 = criterion("active_swappiness", active_swap == expected["vm.swappiness"], 3,
               "vm.swappiness has the requested runtime value", f"vm.swappiness={active_swap or 'unreadable'}")

active_pid = run("sysctl", "-n", "kernel.pid_max")
c2 = criterion("active_pid_max", active_pid == expected["kernel.pid_max"], 3,
               "kernel.pid_max has the requested runtime value", f"kernel.pid_max={active_pid or 'unreadable'}")

persisted = {}
if os.path.isfile(conf):
    for raw in open(conf):
        line = raw.split("#", 1)[0].strip()
        if "=" in line:
            key, value = (part.strip() for part in line.split("=", 1))
            persisted[key.replace("/", ".")] = value
c3 = criterion("persistent_swappiness", persisted.get("vm.swappiness") == expected["vm.swappiness"], 2,
               "vm.swappiness is persisted in the sysctl.d file",
               f"{conf}: vm.swappiness={persisted.get('vm.swappiness')}" if persisted else f"{conf} missing or empty")

c4 = criterion("persistent_pid_max", persisted.get("kernel.pid_max") == expected["kernel.pid_max"], 2,
               "kernel.pid_max is persisted in the sysctl.d file",
               f"{conf}: kernel.pid_max={persisted.get('kernel.pid_max')}" if persisted else f"{conf} missing or empty")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
