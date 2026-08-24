#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
expire_date="$(task_param expire_date)"

usermod -L "$username"
usermod -e "$expire_date" "$username"
