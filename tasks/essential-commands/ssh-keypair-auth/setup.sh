#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

key_user="$(task_param key_user)"
target_user="$(task_param target_user)"

for user in "$key_user" "$target_user"; do
  id -u "$user" &>/dev/null || useradd -m -s /bin/bash "$user"
done

# Ensure a clean starting point for the artifacts this task grades.
key_home="$(getent passwd "$key_user" | cut -d: -f6)"
target_home="$(getent passwd "$target_user" | cut -d: -f6)"
rm -f "$key_home/.ssh/id_ed25519" "$key_home/.ssh/id_ed25519.pub"
rm -f "$target_home/.ssh/authorized_keys"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/ssh-keypair-auth}" > /var/lib/lfcs-simulator/current-task
