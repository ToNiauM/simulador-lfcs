#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

sysctl_file="$(task_param sysctl_file)"

# Clean starting point: forwarding disabled and no stale task file.
rm -f "$sysctl_file"
sysctl -w net.ipv4.ip_forward=0 >/dev/null

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/sysctl-ip-forward}" > /var/lib/lfcs-simulator/current-task
