#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/default-boot-target","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

expected = p["expected_target"]

default = run("systemctl", "get-default")
c1 = criterion("get_default", default == expected, 4, "systemctl get-default reports the requested target",
               default or "unreadable")

link = "/etc/systemd/system/default.target"
target_name = os.path.basename(os.readlink(link)) if os.path.islink(link) else ""
c2 = criterion("persistent_link", target_name == expected, 3,
               "default.target symlink persists the requested target",
               f"{link} -> {os.readlink(link)}" if os.path.islink(link) else "default.target symlink absent")

resolved = run("systemctl", "show", "default.target", "-p", "Id", "--value")
c3 = criterion("target_resolves", resolved == expected, 3,
               "default.target resolves to the requested unit", resolved or "unresolvable")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
