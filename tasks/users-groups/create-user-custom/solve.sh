#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
uid="$(task_param uid)"
home_dir="$(task_param home_dir)"
shell="$(task_param shell)"
comment="$(task_param comment)"

useradd -m -u "$uid" -d "$home_dir" -s "$shell" -c "$comment" "$username"
