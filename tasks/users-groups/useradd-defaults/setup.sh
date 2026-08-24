#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
base_dir="$(task_param base_dir)"

# Clean slate: remove any leftover account, private group and derived base dir.
if id -u "$username" &>/dev/null; then
  userdel -r -f "$username" 2>/dev/null || userdel -f "$username"
fi
if getent group "$username" &>/dev/null; then
  groupdel -f "$username" 2>/dev/null || true
fi
case "$base_dir" in
  /srv/homes-*) rm -rf "$base_dir" ;;
esac

# Reset useradd defaults to the stock Ubuntu values.
useradd -D -b /home >/dev/null
useradd -D -s /bin/sh >/dev/null

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-users-groups/useradd-defaults}" > /var/lib/lfcs-simulator/current-task
