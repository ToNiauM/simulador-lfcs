#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"

# Clean slate: remove any leftover account and private group.
if id -u "$username" &>/dev/null; then
  userdel -r -f "$username" 2>/dev/null || userdel -f "$username"
fi
if getent group "$username" &>/dev/null; then
  groupdel -f "$username" 2>/dev/null || true
fi

# Pre-existing user with a password and default aging values.
useradd -m "$username"
echo "$username:Lab-$(echo "$username" | rev)9" | chpasswd

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-users-groups/password-aging}" > /var/lib/lfcs-simulator/current-task
