#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

user_one="$(task_param user_one)"
user_two="$(task_param user_two)"
group_a="$(task_param group_a)"
group_b="$(task_param group_b)"

# Clean slate: remove any leftover accounts and target groups.
for user in "$user_one" "$user_two"; do
  if id -u "$user" &>/dev/null; then
    userdel -r -f "$user" 2>/dev/null || userdel -f "$user"
  fi
  if getent group "$user" &>/dev/null; then
    groupdel -f "$user" 2>/dev/null || true
  fi
done
for group in "$group_a" "$group_b"; do
  if getent group "$group" &>/dev/null; then
    groupdel -f "$group" 2>/dev/null || true
  fi
done

# Pre-existing users the candidate must not recreate; default private primary groups.
useradd -m "$user_one"
useradd -m "$user_two"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-users-groups/group-membership}" > /var/lib/lfcs-simulator/current-task
