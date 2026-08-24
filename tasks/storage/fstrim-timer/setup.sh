#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

# Start from a known state: timer stopped/disabled and no custom drop-ins.
systemctl disable --now fstrim.timer 2>/dev/null || true
rm -rf /etc/systemd/system/fstrim.timer.d
systemctl daemon-reload
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-storage/fstrim-timer}" > /var/lib/lfcs-simulator/current-task
