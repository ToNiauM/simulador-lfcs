#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
allowed_command="$(task_param allowed_command)"
sudoers_file="$(task_param sudoers_file)"

printf '%s ALL=(root) NOPASSWD: %s\n' "$username" "$allowed_command" > "$sudoers_file"
chmod 0440 "$sudoers_file"
visudo -c -q -f "$sudoers_file"
