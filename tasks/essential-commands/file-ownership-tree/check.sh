#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/file-ownership-tree","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import grp, json, os, pwd, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

tree_dir = p["tree_dir"]
try:
    want_uid = pwd.getpwnam(p["owner_user"]).pw_uid
except KeyError:
    want_uid = -1
try:
    want_gid = grp.getgrnam(p["owner_group"]).gr_gid
except KeyError:
    want_gid = -1

entries = []
if os.path.isdir(tree_dir):
    for root, dirs, files in os.walk(tree_dir):
        for name in dirs + files:
            entries.append(os.path.join(root, name))

top_st = os.lstat(tree_dir) if os.path.isdir(tree_dir) else None
top_ok = top_st is not None and top_st.st_uid == want_uid and top_st.st_gid == want_gid and want_uid >= 0 and want_gid >= 0
c1 = criterion("top_dir_ownership", top_ok, 2, "the tree root has the requested owner and group",
               f"uid={top_st.st_uid} gid={top_st.st_gid}" if top_st else "tree directory missing")

bad_uid = [path for path in entries if os.lstat(path).st_uid != want_uid]
uid_ok = bool(entries) and want_uid >= 0 and not bad_uid
c2 = criterion("all_entries_user", uid_ok, 4, "every file and subdirectory is owned by the requested user",
               "all entries owned by user" if uid_ok else "wrong user on: " + ", ".join(sorted(bad_uid)[:3]) if bad_uid else "tree empty or user missing")

bad_gid = [path for path in entries if os.lstat(path).st_gid != want_gid]
gid_ok = bool(entries) and want_gid >= 0 and not bad_gid
c3 = criterion("all_entries_group", gid_ok, 4, "every file and subdirectory belongs to the requested group",
               "all entries owned by group" if gid_ok else "wrong group on: " + ", ".join(sorted(bad_gid)[:3]) if bad_gid else "tree empty or group missing")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
