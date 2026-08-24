#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/permissions-collaborative-dir","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import grp, json, os, stat, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

group = p["group_name"]
share_dir = p["share_dir"]
users = (p["user_a"], p["user_b"])
mode_expected = int(p["dir_mode"], 8)

def member_groups(user):
    out = subprocess.run(["id", "-nG", user], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout
    return out.split()

membership = {user: group in member_groups(user) for user in users}
c1 = criterion("users_in_group", all(membership.values()), 3, "both users are supplementary members of the group",
               ", ".join(f"{u}:{'ok' if ok else 'not a member'}" for u, ok in membership.items()))

st = None
try:
    st = os.stat(share_dir)
except OSError:
    pass
is_dir = st is not None and stat.S_ISDIR(st.st_mode)
group_ok = False
group_actual = "-"
if is_dir:
    try:
        group_actual = grp.getgrgid(st.st_gid).gr_name
    except KeyError:
        group_actual = str(st.st_gid)
    group_ok = group_actual == group
c2 = criterion("dir_group_owner", is_dir and group_ok, 3, "directory exists and is group-owned by the project group",
               f"{share_dir} group={group_actual}" if is_dir else "directory missing")

setgid_ok = is_dir and bool(st.st_mode & stat.S_ISGID)
c3 = criterion("setgid_bit", setgid_ok, 2, "setgid bit is set on the directory",
               oct(st.st_mode & 0o7777) if is_dir else "directory missing")

mode_ok = is_dir and (st.st_mode & 0o7777) == mode_expected
c4 = criterion("dir_mode", mode_ok, 2, "directory mode grants full access to owner and group only",
               oct(st.st_mode & 0o7777) if is_dir else "directory missing")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
