#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

group="$(task_param group_name)"
share_dir="$(task_param share_dir)"
user_a="$(task_param user_a)"
user_b="$(task_param user_b)"
mode="$(task_param dir_mode)"

usermod -aG "$group" "$user_a"
usermod -aG "$group" "$user_b"
mkdir -p "$share_dir"
chgrp "$group" "$share_dir"
chmod "$mode" "$share_dir"
