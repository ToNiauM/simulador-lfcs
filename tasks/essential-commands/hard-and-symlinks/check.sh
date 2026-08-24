#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/hard-and-symlinks","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

hard_target = p["hard_target"]
hard_link = p["hard_link"]
sym_target = p["sym_target"]
sym_link = p["sym_link"]

def lstat(path):
    try:
        return os.lstat(path)
    except OSError:
        return None

t_st = lstat(hard_target)
h_st = lstat(hard_link)
hard_is_file = h_st is not None and not os.path.islink(hard_link) and os.path.isfile(hard_link)
c1 = criterion("hard_link_not_symlink", hard_is_file, 2, "hard link path exists as a regular file (not a symlink)",
               "regular file" if hard_is_file else ("is a symlink" if h_st and os.path.islink(hard_link) else "missing"))

same_inode = hard_is_file and t_st is not None and (h_st.st_ino, h_st.st_dev) == (t_st.st_ino, t_st.st_dev) and t_st.st_nlink >= 2
c2 = criterion("hard_link_same_inode", same_inode, 3, "hard link shares the inode of the target file",
               f"inode link={h_st.st_ino} target={t_st.st_ino} nlink={t_st.st_nlink}" if (h_st and t_st) else "link or target missing")

is_symlink = os.path.islink(sym_link)
c3 = criterion("symlink_is_symlink", is_symlink, 2, "symbolic link path exists and is a symlink",
               "symlink" if is_symlink else ("exists but is not a symlink" if lstat(sym_link) else "missing"))

points_ok = False
evidence = "symlink missing"
if is_symlink:
    raw = os.readlink(sym_link)
    resolved = os.path.realpath(sym_link)
    points_ok = os.path.exists(sym_link) and resolved == os.path.realpath(sym_target)
    evidence = f"{sym_link} -> {raw}"
c4 = criterion("symlink_resolves_to_target", points_ok, 3, "symbolic link resolves to the requested target", evidence)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
