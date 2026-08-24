#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
limits_file="$(task_param limits_file)"

# Clean slate: remove any leftover account, private group and limits fragment.
if id -u "$username" &>/dev/null; then
  userdel -r -f "$username" 2>/dev/null || userdel -f "$username"
fi
if getent group "$username" &>/dev/null; then
  groupdel -f "$username" 2>/dev/null || true
fi
rm -f "$limits_file"

# Pre-existing user the limits must apply to.
useradd -m "$username"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-users-groups/limits-user-resources}" > /var/lib/lfcs-simulator/current-task
