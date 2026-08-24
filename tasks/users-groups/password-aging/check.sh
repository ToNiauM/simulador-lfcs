#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"users-groups/password-aging","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

username = p["username"]
fields = None
try:
    for line in open("/etc/shadow"):
        parts = line.rstrip("\n").split(":")
        if parts and parts[0] == username:
            fields = parts
            break
except OSError:
    fields = None
def shadow_field(index):
    if fields is None or len(fields) <= index:
        return ""
    return fields[index]

password_set = bool(shadow_field(1)) and not shadow_field(1).startswith("!") and shadow_field(1) not in ("*", "x")
c1 = criterion("account_usable", fields is not None and password_set, 1, "account exists and its password is set and not locked", (shadow_field(1)[:4] + "...") if fields else "no shadow entry")
c2 = criterion("max_days", shadow_field(4) == str(p["max_days"]), 3, "maximum password age matches", f"shadow max field: {shadow_field(4) or 'empty'}")
c3 = criterion("min_days", shadow_field(3) == str(p["min_days"]), 3, "minimum password age matches", f"shadow min field: {shadow_field(3) or 'empty'}")
c4 = criterion("warn_days", shadow_field(5) == str(p["warn_days"]), 3, "warning period matches", f"shadow warn field: {shadow_field(5) or 'empty'}")
criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
