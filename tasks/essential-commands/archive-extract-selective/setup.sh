#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

archive="$(task_param archive_path)"
dest_dir="$(task_param dest_dir)"

rm -f "$archive"
rm -rf "$dest_dir"

# Build the archive deterministically with python's tarfile (fixed mtime/owner).
python3 - "$LFCS_PARAMS_FILE" <<'PY'
import io, json, sys, tarfile

payload = json.load(open(sys.argv[1]))
p = payload["params"]
app = p["app_name"]
token = p["fixture_token"]

members = [
    f"{app}/conf/app.conf",
    f"{app}/conf/db.conf",
    f"{app}/conf/logging.conf",
    f"{app}/docs/readme.md",
    f"{app}/bin/run.sh",
    f"{app}/data/sample.csv",
]

with tarfile.open(p["archive_path"], "w:gz") as tar:
    for rel in members:
        body = "".join(f"lfcs-fixture:{token}:{rel}:{i}\n" for i in range(3)).encode()
        info = tarfile.TarInfo(rel)
        info.size = len(body)
        info.mode = 0o644
        info.mtime = 0
        tar.addfile(info, io.BytesIO(body))
PY

mkdir -p "$dest_dir"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/archive-extract-selective}" > /var/lib/lfcs-simulator/current-task
