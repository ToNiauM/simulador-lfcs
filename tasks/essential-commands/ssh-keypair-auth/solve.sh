#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

key_user="$(task_param key_user)"
target_user="$(task_param target_user)"
key_type="$(task_param key_type)"

key_home="$(getent passwd "$key_user" | cut -d: -f6)"
target_home="$(getent passwd "$target_user" | cut -d: -f6)"

install -d -m 700 -o "$key_user" -g "$key_user" "$key_home/.ssh"
runuser -u "$key_user" -- ssh-keygen -q -t "$key_type" -N '' -f "$key_home/.ssh/id_$key_type"

install -d -m 700 -o "$target_user" -g "$target_user" "$target_home/.ssh"
cat "$key_home/.ssh/id_$key_type.pub" >> "$target_home/.ssh/authorized_keys"
chown "$target_user:$target_user" "$target_home/.ssh/authorized_keys"
chmod 600 "$target_home/.ssh/authorized_keys"
