#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
skel_file="$(task_param skel_file)"

# Clean slate: remove any leftover account, private group and skel fixture.
if id -u "$username" &>/dev/null; then
  userdel -r -f "$username" 2>/dev/null || userdel -f "$username"
fi
if getent group "$username" &>/dev/null; then
  groupdel -f "$username" 2>/dev/null || true
fi
rm -f "/etc/skel/$skel_file"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-users-groups/skel-onboarding}" > /var/lib/lfcs-simulator/current-task
