#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
uid="$(task_param uid)"
home_dir="$(task_param home_dir)"

groupadd -r -g "$uid" "$username" 2>/dev/null || groupadd -r "$username"
useradd -r -u "$uid" -g "$username" -d "$home_dir" -m -s /usr/sbin/nologin "$username"
