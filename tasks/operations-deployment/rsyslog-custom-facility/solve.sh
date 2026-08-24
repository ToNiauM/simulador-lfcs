#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

facility="$(task_param facility)"
conf_file="$(task_param conf_file)"
log_file="$(task_param log_file)"
token="$(task_param test_token)"

printf '%s.*\t%s\n' "$facility" "$log_file" > "$conf_file"
systemctl restart rsyslog

logger -p "${facility}.info" -t lfcs-lab "test message $token"

# Wait for rsyslog to flush the message to disk (bounded, deterministic outcome).
for _ in $(seq 1 40); do
  if [[ -f "$log_file" ]] && grep -q -- "$token" "$log_file"; then
    exit 0
  fi
  sleep 0.25
done
echo "test message was not written to $log_file" >&2
exit 1
