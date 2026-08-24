#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

base="$(task_param base_dir)"
report="$(task_param report_file)"

rm -rf "$base"
rm -f "$report"
mkdir -p "$base"

# Deterministic fixture tree: sizes and layout derive only from params.
python3 - "$LFCS_PARAMS_FILE" <<'PY'
import hashlib, json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
base = p["base_dir"]
threshold = int(p["threshold_kib"])
token = p["fixture_token"]

OLD = "2021-03-15 08:30:00"  # fixed timestamp far in the past

def material(name, size):
    # Deterministic byte content derived from token + name.
    chunk = hashlib.sha256(f"{token}:{name}".encode()).hexdigest().encode()
    data = (chunk * (size // len(chunk) + 1))[:size]
    return data

# (relative path, size factor, old?) — factors keep sizes strictly above or
# strictly below the threshold, never on the boundary.
spec = [
    ("logs/app.log",        threshold * 2,      True),
    ("logs/audit.log",      threshold * 3,      True),
    ("data/archive.bin",    threshold * 2 + 7,  True),
    ("data/current.bin",    threshold * 2,      False),  # large but recent
    ("logs/recent.log",     threshold * 4,      False),  # large but recent
    ("cache/old-small.dat", threshold // 2,     True),   # old but small
    ("cache/tiny.dat",      threshold // 4,     True),
    ("data/notes.txt",      threshold // 3,     False),
]
old_paths = []
for rel, size_kib, old in spec:
    path = os.path.join(base, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(material(rel, size_kib * 1024))
    if old:
        old_paths.append(path)
print("\n".join(old_paths))
PY

# Age the "old" files with a fixed, deterministic timestamp.
python3 - "$LFCS_PARAMS_FILE" <<'PY' | while IFS= read -r path; do touch -d '2021-03-15 08:30:00' "$path"; done
import json, os, sys
payload = json.load(open(sys.argv[1]))
p = payload["params"]
base = p["base_dir"]
for rel in ("logs/app.log", "logs/audit.log", "data/archive.bin", "cache/old-small.dat", "cache/tiny.dat"):
    print(os.path.join(base, rel))
PY

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/find-large-files}" > /var/lib/lfcs-simulator/current-task
