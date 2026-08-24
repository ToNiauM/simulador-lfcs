#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

user_one="$(task_param user_one)"
user_two="$(task_param user_two)"
group_name="$(task_param group_name)"
shared_dir="$(task_param shared_dir)"

groupadd "$group_name"
usermod -aG "$group_name" "$user_one"
usermod -aG "$group_name" "$user_two"
mkdir -p "$shared_dir"
chgrp "$group_name" "$shared_dir"
chmod 2770 "$shared_dir"
