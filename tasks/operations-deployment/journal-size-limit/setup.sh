#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

dropin_file="$(task_param dropin_file)"

# Clean slate: the candidate must create the drop-in.
rm -f "$dropin_file"

# Ensure journald is running with defaults so a stale test config never lingers.
systemctl restart systemd-journald

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/journal-size-limit}" > /var/lib/lfcs-simulator/current-task
