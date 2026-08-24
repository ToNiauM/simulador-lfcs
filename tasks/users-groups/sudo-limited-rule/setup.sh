#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
sudoers_file="$(task_param sudoers_file)"

# Clean slate: remove any leftover account, private group and sudoers fragment.
if id -u "$username" &>/dev/null; then
  userdel -r -f "$username" 2>/dev/null || userdel -f "$username"
fi
if getent group "$username" &>/dev/null; then
  groupdel -f "$username" 2>/dev/null || true
fi
rm -f "$sudoers_file"

# Pre-existing unprivileged user.
useradd -m "$username"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-users-groups/sudo-limited-rule}" > /var/lib/lfcs-simulator/current-task
