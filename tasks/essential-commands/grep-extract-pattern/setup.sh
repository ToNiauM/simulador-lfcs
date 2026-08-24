#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

log_file="$(task_param log_file)"
out_file="$(task_param out_file)"

rm -f "$log_file" "$out_file"

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import hashlib, json, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
token = p["fixture_token"]
levels = ("INFO", "ERROR", "WARN", "DEBUG", "CRIT")

lines = []
for i in range(48):
    pick = hashlib.sha256(f"{token}:{i}".encode()).hexdigest()
    level = levels[int(pick[:2], 16) % len(levels)]
    lines.append(f"{level} 2025-{(i % 12) + 1:02d}-{(i % 27) + 1:02d} svc=worker id={pick[2:10]} msg=event-{i:03d}")
# Trap lines: level name appears but not as the leading field.
lines.append(f"INFO 2025-06-01 svc=relay id={token} msg=upstream returned {p['level']} once")
lines.append(f"DEBUG 2025-06-02 svc=relay id={token} msg={p['level']}-counter reset")
with open(p["log_file"], "w") as handle:
    handle.write("\n".join(lines) + "\n")
PY

# Guarantee at least three matching lines regardless of the hash draw.
level="$(task_param level)"
token="$(task_param fixture_token)"
for i in 1 2 3; do
  printf '%s 2025-07-0%d svc=core id=%s msg=forced-%d\n' "$level" "$i" "$token" "$i" >> "$log_file"
done

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/grep-extract-pattern}" > /var/lib/lfcs-simulator/current-task
