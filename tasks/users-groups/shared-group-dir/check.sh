#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"users-groups/shared-group-dir","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import grp, json, os, stat, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}
def supplementary(user):
    out = subprocess.run(["id", "-nG", user], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
    return out.split() if out else []

group_name = p["group_name"]
shared_dir = p["shared_dir"]
try:
    group = grp.getgrnam(group_name)
except KeyError:
    group = None
c1 = criterion("group_exists", group is not None, 2, "collaboration group exists", f"gid={group.gr_gid}" if group else "group missing")
m1, m2 = supplementary(p["user_one"]), supplementary(p["user_two"])
members_ok = group is not None and group_name in m1 and group_name in m2
c2 = criterion("members", members_ok, 2, "both users are supplementary members of the group", f"{p['user_one']}:{','.join(m1) or '-'} {p['user_two']}:{','.join(m2) or '-'}")
st = None
if os.path.isdir(shared_dir):
    st = os.stat(shared_dir)
group_owner_ok = st is not None and group is not None and st.st_gid == group.gr_gid
c3 = criterion("dir_group", group_owner_ok, 2, "shared directory exists and is group-owned by the collaboration group", f"gid={st.st_gid}" if st else "directory missing")
mode = stat.S_IMODE(st.st_mode) if st else 0
c4 = criterion("setgid", st is not None and bool(mode & stat.S_ISGID), 2, "setgid bit keeps new files group-owned by the group", oct(mode) if st else "directory missing")
perms_ok = st is not None and (mode & 0o070) == 0o070 and (mode & 0o002) == 0
c5 = criterion("group_write", perms_ok, 2, "group has full access and others have no write access", oct(mode) if st else "directory missing")
criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
