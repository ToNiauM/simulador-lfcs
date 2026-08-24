#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/archive-extract-selective","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, sys, tarfile

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

archive = p["archive_path"]
dest = p["dest_dir"]
app = p["app_name"]
subdir = p["wanted_subdir"]
prefix = f"{app}/{subdir}/"

# Read the archive (read-only) to learn expected members and contents.
wanted, unwanted = {}, []
archive_ok = False
try:
    with tarfile.open(archive, "r:gz") as tar:
        for member in tar.getmembers():
            if not member.isfile():
                continue
            name = member.name.lstrip("./")
            if name.startswith(prefix):
                wanted[name] = tar.extractfile(member).read()
            else:
                unwanted.append(name)
    archive_ok = bool(wanted)
except (OSError, tarfile.TarError):
    pass
c1 = criterion("archive_intact", archive_ok, 2, "release archive is still present and readable",
               archive if archive_ok else f"{archive} missing or unreadable")

missing = [name for name in sorted(wanted) if not os.path.isfile(os.path.join(dest, name))]
present_ok = archive_ok and not missing
c2 = criterion("wanted_files_extracted", present_ok, 3,
               "all requested members exist under the destination with their archive paths",
               "all extracted" if present_ok else "missing: " + ", ".join(missing) if missing else "archive unreadable")

corrupt = []
if archive_ok:
    for name, body in wanted.items():
        path = os.path.join(dest, name)
        if os.path.isfile(path):
            with open(path, "rb") as handle:
                if handle.read() != body:
                    corrupt.append(name)
content_ok = present_ok and not corrupt
c3 = criterion("contents_match", content_ok, 3, "extracted file contents match the archive exactly",
               "contents match" if content_ok else "differs: " + ", ".join(corrupt) if corrupt else "files missing")

extras = []
for root, _dirs, files in os.walk(dest):
    for name in files:
        rel = os.path.relpath(os.path.join(root, name), dest)
        if rel not in wanted:
            extras.append(rel)
no_extras = os.path.isdir(dest) and not extras
c4 = criterion("no_other_members", no_extras, 2, "no other archive member was extracted into the destination",
               "destination clean" if no_extras else "unexpected files: " + ", ".join(sorted(extras)[:4]) if extras else "destination missing")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
