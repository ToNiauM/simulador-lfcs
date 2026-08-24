#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

user="$(task_param username)"
script="$(task_param script_path)"
minute="$(task_param minute)"
hour="$(task_param hour)"

printf '%s %s * * * %s\n' "$minute" "$hour" "$script" | crontab -u "$user" -
