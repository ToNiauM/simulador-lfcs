#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"users-groups/system-service-account","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import grp, json, os, pwd, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

username = p["username"]
try:
    entry = pwd.getpwnam(username)
except KeyError:
    entry = None
c1 = criterion("user_uid", entry is not None and entry.pw_uid == int(p["uid"]), 3, "system account exists with the requested UID", f"uid={entry.pw_uid}" if entry else "user missing")
group_ok = False
group_evidence = "user missing"
if entry is not None:
    try:
        group = grp.getgrgid(entry.pw_gid)
        group_ok = group.gr_name == username and group.gr_gid < 1000
        group_evidence = f"primary group {group.gr_name} (gid={group.gr_gid})"
    except KeyError:
        group_evidence = f"gid {entry.pw_gid} has no group entry"
c2 = criterion("primary_group", group_ok, 2, "primary group is a dedicated system group", group_evidence)
nologin_shells = ("/usr/sbin/nologin", "/sbin/nologin", "/bin/false", "/usr/bin/false")
c3 = criterion("shell_nologin", entry is not None and entry.pw_shell in nologin_shells, 2, "shell prevents interactive login", entry.pw_shell if entry else "user missing")
home_ok = entry is not None and entry.pw_dir == p["home_dir"] and os.path.isdir(p["home_dir"])
c4 = criterion("home_dir", home_ok, 2, "home directory field matches and the directory exists", entry.pw_dir if entry else "user missing")
hash_field = ""
try:
    for line in open("/etc/shadow"):
        parts = line.rstrip("\n").split(":")
        if parts and parts[0] == username:
            hash_field = parts[1] if len(parts) > 1 else ""
            break
except OSError:
    pass
c5 = criterion("no_password", entry is not None and (hash_field.startswith("!") or hash_field.startswith("*")), 1, "account has no usable password", (hash_field[:6] + "...") if hash_field else "empty hash field")
criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
