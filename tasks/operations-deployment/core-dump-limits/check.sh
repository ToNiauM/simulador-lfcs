#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/core-dump-limits","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

limits_file = p["limits_file"]
sysctl_file = p["sysctl_file"]
key = p["sysctl_key"]
value = p["sysctl_value"]

limits_ok = False
limits_evidence = f"{limits_file} missing"
if os.path.isfile(limits_file):
    limits_evidence = f"{limits_file}: no '* hard core 0' rule"
    for line in open(limits_file):
        fields = line.split("#", 1)[0].split()
        if fields == ["*", "hard", "core", "0"]:
            limits_ok = True
            limits_evidence = line.strip()
            break
c1 = criterion("limits_rule", limits_ok, 4, "hard core size limit 0 for all users in limits.d file", limits_evidence)

persist_ok = False
persist_evidence = f"{sysctl_file} missing"
if os.path.isfile(sysctl_file):
    persist_evidence = f"{sysctl_file}: no '{key} = {value}' entry"
    for line in open(sysctl_file):
        text = line.split("#", 1)[0].strip()
        if "=" not in text:
            continue
        found_key, found_value = (part.strip() for part in text.split("=", 1))
        if found_key == key and found_value == value:
            persist_ok = True
            persist_evidence = line.strip()
            break
c2 = criterion("sysctl_persistent", persist_ok, 3, "kernel parameter persisted in sysctl.d file", persist_evidence)

proc_path = "/proc/sys/" + key.replace(".", "/")
try:
    active = open(proc_path).read().strip()
except OSError:
    active = ""
c3 = criterion("sysctl_active", active == value, 3, "kernel parameter active on the running system", f"{proc_path} = {active or 'unreadable'}")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
