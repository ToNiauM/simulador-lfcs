#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

data_dir="$(task_param data_dir)"
archive="$(task_param archive_path)"

rm -rf "$data_dir"
rm -f "$archive"

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
data_dir = p["data_dir"]
token = p["fixture_token"]
ext = p["exclude_glob"].lstrip("*")  # ".tmp" / ".bak" / ".cache"

def write(rel, mode=0o644):
    path = os.path.join(data_dir, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    body = "".join(f"lfcs-fixture:{token}:{rel}:{i}\n" for i in range(4))
    with open(path, "w") as handle:
        handle.write(body)
    os.chmod(path, mode)

write("notes/readme.txt")
write("notes/changelog.txt")
write("data/records.csv")
write("data/index.db")
write("scripts/run.sh", 0o750)
# Files that must be excluded from the backup.
write(f"data/session{ext}")
write(f"notes/draft{ext}")
write(f"scratch{ext}")
PY

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/tar-backup-compress}" > /var/lib/lfcs-simulator/current-task
