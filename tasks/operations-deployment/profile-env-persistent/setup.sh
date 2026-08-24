#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

script_path="$(task_param script_path)"

# Ensure a clean slate: the target profile script must not exist yet.
rm -f "$script_path"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/profile-env-persistent}" > /var/lib/lfcs-simulator/current-task
