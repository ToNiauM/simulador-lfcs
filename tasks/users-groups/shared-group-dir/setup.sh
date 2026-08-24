#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

user_one="$(task_param user_one)"
user_two="$(task_param user_two)"
group_name="$(task_param group_name)"
shared_dir="$(task_param shared_dir)"

# Clean slate: remove any leftover accounts, group and shared directory.
for user in "$user_one" "$user_two"; do
  if id -u "$user" &>/dev/null; then
    userdel -r -f "$user" 2>/dev/null || userdel -f "$user"
  fi
  if getent group "$user" &>/dev/null; then
    groupdel -f "$user" 2>/dev/null || true
  fi
done
if getent group "$group_name" &>/dev/null; then
  groupdel -f "$group_name" 2>/dev/null || true
fi
case "$shared_dir" in
  /srv/colab-*) rm -rf "$shared_dir" ;;
esac

# Pre-existing users that must join the collaboration group.
useradd -m "$user_one"
useradd -m "$user_two"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-users-groups/shared-group-dir}" > /var/lib/lfcs-simulator/current-task
