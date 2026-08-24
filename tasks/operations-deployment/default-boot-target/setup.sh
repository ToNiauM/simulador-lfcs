#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

initial="$(task_param initial_target)"

systemctl set-default "$initial"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/default-boot-target}" > /var/lib/lfcs-simulator/current-task
