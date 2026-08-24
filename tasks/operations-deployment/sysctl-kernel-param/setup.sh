#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

conf="$(task_param conf_file)"

# Start from the Ubuntu defaults so the requested values are not yet applied.
rm -f "$conf"
sysctl -w vm.swappiness=60 >/dev/null
sysctl -w kernel.pid_max=4194304 >/dev/null

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/sysctl-kernel-param}" > /var/lib/lfcs-simulator/current-task
