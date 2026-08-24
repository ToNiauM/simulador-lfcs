#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"users-groups/limits-user-resources","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

username = p["username"]
path = p["limits_file"]
exists = os.path.isfile(path)
c1 = criterion("file_present", exists, 2, "limits drop-in file exists under /etc/security/limits.d", path if exists else "file missing")
soft_ok = hard_ok = False
soft_line = hard_line = ""
syntax_ok = exists
bad_line = ""
if exists:
    for raw in open(path):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if len(fields) != 4:
            syntax_ok = False
            bad_line = line
            continue
        domain, ltype, item, value = fields
        if item == "nofile" and not value.isdigit():
            syntax_ok = False
            bad_line = line
            continue
        if domain == username and item == "nofile":
            if ltype in ("soft", "-") and value == str(p["soft_nofile"]):
                soft_ok = True
                soft_line = line
            if ltype in ("hard", "-") and value == str(p["hard_nofile"]):
                hard_ok = True
                hard_line = line
c2 = criterion("soft_nofile", soft_ok, 3, "soft nofile limit for the user matches", soft_line or "no matching soft entry")
c3 = criterion("hard_nofile", hard_ok, 3, "hard nofile limit for the user matches", hard_line or "no matching hard entry")
c4 = criterion("syntax_valid", syntax_ok, 2, "every entry in the file uses valid limits.conf syntax", bad_line or ("all entries well-formed" if exists else "file missing"))
criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
