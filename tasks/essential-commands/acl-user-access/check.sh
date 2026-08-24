#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/acl-user-access","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

user = p["acl_user"]
data_dir = p["data_dir"]
files = [os.path.join(data_dir, p["file_a"]), os.path.join(data_dir, p["file_b"])]

def read_acl(path):
    proc = subprocess.run(["getfacl", "-p", "--absolute-names", path],
                          text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    info = {"owner": None, "group": None, "entries": {}}
    if proc.returncode != 0:
        return None
    for line in proc.stdout.splitlines():
        line = line.strip()
        if line.startswith("# owner:"):
            info["owner"] = line.split(":", 1)[1].strip()
        elif line.startswith("# group:"):
            info["group"] = line.split(":", 1)[1].strip()
        elif line and not line.startswith("#"):
            entry, _, comment = line.partition("#")
            perms_effective = comment.replace("effective:", "").strip() if "effective:" in comment else None
            fields = entry.strip().split(":")
            key = ":".join(fields[:-1])
            info["entries"][key] = perms_effective or fields[-1]
    return info

dir_acl = read_acl(data_dir) if os.path.isdir(data_dir) else None

dir_user_perms = dir_acl["entries"].get(f"user:{user}", "") if dir_acl else ""
c1 = criterion("dir_access_acl", dir_user_perms == "rwx", 3,
               "directory ACL grants the user effective rwx",
               f"user:{user}:{dir_user_perms or 'absent'}" if dir_acl else "directory or getfacl unavailable")

def_perms = dir_acl["entries"].get(f"default:user:{user}", "") if dir_acl else ""
c2 = criterion("dir_default_acl", def_perms == "rwx", 3,
               "default ACL grants the user rwx on future entries",
               f"default:user:{user}:{def_perms or 'absent'}" if dir_acl else "directory or getfacl unavailable")

file_state = []
files_ok = True
for path in files:
    acl = read_acl(path) if os.path.isfile(path) else None
    perms = acl["entries"].get(f"user:{user}", "") if acl else ""
    ok = "r" in perms and "w" in perms
    files_ok = files_ok and ok
    file_state.append(f"{os.path.basename(path)}:{perms or 'absent'}")
c3 = criterion("files_acl_rw", files_ok and bool(files), 2,
               "each existing file grants the user read and write via ACL",
               ", ".join(file_state))

base_ok = False
evidence = "directory or getfacl unavailable"
if dir_acl:
    mode = p["dir_base_mode"]
    digits = [int(ch) for ch in mode]
    def rwx(d):
        return f"{'r' if d & 4 else '-'}{'w' if d & 2 else '-'}{'x' if d & 1 else '-'}"
    base_ok = (dir_acl["owner"] == "root" and dir_acl["group"] == "root"
               and dir_acl["entries"].get("user:") == rwx(digits[0])
               and dir_acl["entries"].get("group:") == rwx(digits[1])
               and dir_acl["entries"].get("other:") == rwx(digits[2]))
    evidence = (f"owner={dir_acl['owner']}:{dir_acl['group']} user::{dir_acl['entries'].get('user:')} "
                f"group::{dir_acl['entries'].get('group:')} other::{dir_acl['entries'].get('other:')}")
c4 = criterion("base_perms_unchanged", base_ok, 2,
               "owner, group and traditional permission bits are unchanged", evidence)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
