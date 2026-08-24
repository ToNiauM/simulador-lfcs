#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
home_dir="$(task_param home_dir)"

# Clean slate: remove any leftover account, group and home directory.
if id -u "$username" &>/dev/null; then
  userdel -r -f "$username" 2>/dev/null || userdel -f "$username"
fi
if getent group "$username" &>/dev/null; then
  groupdel -f "$username" 2>/dev/null || true
fi
case "$home_dir" in
  /var/lib/svc*) rm -rf "$home_dir" ;;
esac

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-users-groups/system-service-account}" > /var/lib/lfcs-simulator/current-task
