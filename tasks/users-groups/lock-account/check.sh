#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"users-groups/lock-account","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import datetime, json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

username = p["username"]
expire_date = p["expire_date"]
fields = None
try:
    for line in open("/etc/shadow"):
        parts = line.rstrip("\n").split(":")
        if parts and parts[0] == username:
            fields = parts
            break
except OSError:
    fields = None
c1 = criterion("user_exists", fields is not None, 1, "account still exists", "shadow entry found" if fields else "no shadow entry")
hash_field = fields[1] if fields and len(fields) > 1 else ""
locked = hash_field.startswith("!")
c2 = criterion("password_locked", locked, 3, "password is locked in /etc/shadow", (hash_field[:6] + "...") if hash_field else "empty hash field")
status = subprocess.run(["passwd", "-S", username], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
status_flag = status.split()[1] if len(status.split()) > 1 else ""
c3 = criterion("passwd_status", status_flag == "L", 2, "passwd -S reports the account as locked", status or "no status output")
year, month, day = (int(part) for part in expire_date.split("-"))
expected_days = (datetime.date(year, month, day) - datetime.date(1970, 1, 1)).days
expire_field = fields[7] if fields and len(fields) > 7 else ""
c4 = criterion("expire_date", expire_field == str(expected_days), 4, "account expiration date matches the required date", f"shadow expire field: {expire_field or 'empty'} (expected {expected_days})")
criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
