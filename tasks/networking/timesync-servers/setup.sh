#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

ntp1="$(task_param ntp_server_1)"

# Idempotency: drop any previous drop-in referencing our seeded server, then
# make sure the service starts from a non-configured state.
if [[ -d /etc/systemd/timesyncd.conf.d ]]; then
  while IFS= read -r conf; do
    rm -f "$conf"
  done < <(grep -l -- "$ntp1" /etc/systemd/timesyncd.conf.d/*.conf 2>/dev/null || true)
fi
systemctl disable --now systemd-timesyncd.service >/dev/null 2>&1 || true

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/timesync-servers}" > /var/lib/lfcs-simulator/current-task
