#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"users-groups/create-user-custom","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, pwd, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

username = p["username"]
try:
    entry = pwd.getpwnam(username)
except KeyError:
    entry = None
c1 = criterion("user_uid", entry is not None and entry.pw_uid == int(p["uid"]), 2, "user exists with the requested UID", f"uid={entry.pw_uid}" if entry else "user missing")
home_ok = entry is not None and entry.pw_dir == p["home_dir"] and os.path.isdir(p["home_dir"])
c2 = criterion("home_dir", home_ok, 2, "home directory field matches and the directory exists", entry.pw_dir if entry else "user missing")
owner_ok = False
owner_evidence = "directory missing"
if entry is not None and os.path.isdir(p["home_dir"]):
    st = os.stat(p["home_dir"])
    owner_ok = st.st_uid == entry.pw_uid
    owner_evidence = f"owner uid={st.st_uid}"
c3 = criterion("home_owner", owner_ok, 2, "home directory is owned by the user", owner_evidence)
c4 = criterion("shell", entry is not None and entry.pw_shell == p["shell"], 2, "login shell matches the requested shell", entry.pw_shell if entry else "user missing")
c5 = criterion("comment", entry is not None and entry.pw_gecos == p["comment"], 2, "comment (GECOS) field matches", entry.pw_gecos if entry else "user missing")
criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
