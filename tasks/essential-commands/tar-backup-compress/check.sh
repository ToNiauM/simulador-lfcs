#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/tar-backup-compress","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import fnmatch, json, os, sys, tarfile

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

data_dir = p["data_dir"]
archive = p["archive_path"]
exclude = p["exclude_glob"]
script_mode = int(p["script_mode"], 8)

members = []
readable = False
try:
    with tarfile.open(archive, "r:gz") as tar:
        members = [m for m in tar.getmembers()]
    readable = True
except (OSError, tarfile.TarError) as exc:
    evidence = f"{archive}: {exc}"
c1 = criterion("archive_gzip_readable", readable, 2, "archive exists and is a readable gzip tar",
               archive if readable else evidence)

def norm(name):
    return name.lstrip("./").lstrip("/")

file_members = {norm(m.name): m for m in members if m.isfile()}

def find_member(rel):
    # Accept any archiving root: dados-x/rel, srv/dados-x/rel, rel, ./rel ...
    for name, member in file_members.items():
        if name == rel or name.endswith("/" + rel):
            return member
    return None

# Expected relative paths: everything currently in data_dir not matching the glob.
expected, excluded_present = [], []
for root, _dirs, files in os.walk(data_dir):
    for name in files:
        rel = os.path.relpath(os.path.join(root, name), data_dir)
        if fnmatch.fnmatch(name, exclude):
            excluded_present.append(rel)
        else:
            expected.append(rel)

missing = [rel for rel in sorted(expected) if find_member(rel) is None] if readable else sorted(expected)
c2 = criterion("contains_all_files", readable and not missing, 3, "all non-excluded files are in the archive",
               "all present" if readable and not missing else "missing from archive: " + ", ".join(missing))

leaked = [name for name in sorted(file_members) if fnmatch.fnmatch(os.path.basename(name), exclude)]
c3 = criterion("excludes_pattern", readable and not leaked, 3, "no file matching the exclude pattern is archived",
               "pattern excluded" if readable and not leaked else "excluded files found: " + ", ".join(leaked) if leaked else "archive unreadable")

script_member = find_member("scripts/run.sh") if readable else None
mode_ok = script_member is not None and (script_member.mode & 0o777) == script_mode
c4 = criterion("preserves_permissions", mode_ok, 2, "file permissions are preserved in the archive",
               oct(script_member.mode & 0o777) if script_member else "scripts/run.sh not found in archive")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
