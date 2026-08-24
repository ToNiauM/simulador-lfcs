#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

app="$(task_param app_name)"
log_path="$(task_param log_path)"

mkdir -p "$(dirname "$log_path")"
: > "$log_path"
for i in $(seq 1 20); do
  printf '%s entry %02d for %s\n' "2026-01-01T00:00:00" "$i" "$app" >> "$log_path"
done
chmod 0644 "$log_path"

rm -f "/etc/logrotate.d/$app"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/logrotate-app}" > /var/lib/lfcs-simulator/current-task
