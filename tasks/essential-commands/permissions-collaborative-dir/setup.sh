#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

group="$(task_param group_name)"
share_dir="$(task_param share_dir)"
user_a="$(task_param user_a)"
user_b="$(task_param user_b)"

# Idempotent fixture: group and users exist, but users are NOT members yet.
groupadd -f "$group"
for user in "$user_a" "$user_b"; do
  id "$user" &>/dev/null || useradd -m -s /bin/bash "$user"
  gpasswd -d "$user" "$group" &>/dev/null || true
done
rm -rf "$share_dir"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/permissions-collaborative-dir}" > /var/lib/lfcs-simulator/current-task
