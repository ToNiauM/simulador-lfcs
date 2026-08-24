#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

data_file="$(task_param data_file)"
report_file="$(task_param report_file)"

rm -f "$data_file" "$report_file"
mkdir -p "$(dirname "$data_file")"

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import hashlib, json, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
token = p["fixture_token"]

# Five deterministic usernames with five distinct counts.
names = [f"user{hashlib.sha256(f'{token}:name:{i}'.encode()).hexdigest()[:5]}" for i in range(5)]
counts = [3, 5, 8, 12, 17]
# Deterministic shuffle of count assignment.
order = sorted(range(5), key=lambda i: hashlib.sha256(f"{token}:order:{i}".encode()).hexdigest())
assignment = {names[i]: counts[order[i]] for i in range(5)}

# Interleave lines deterministically so equal names are not adjacent.
pool = []
for name, count in assignment.items():
    pool.extend([name] * count)
scattered = sorted(range(len(pool)), key=lambda i: hashlib.sha256(f"{token}:pos:{i}".encode()).hexdigest())
lines = [pool[i] for i in scattered]

with open(p["data_file"], "w") as handle:
    handle.write("\n".join(lines) + "\n")
PY

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/sort-uniq-count}" > /var/lib/lfcs-simulator/current-task
