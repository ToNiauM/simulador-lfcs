#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

user_one="$(task_param user_one)"
user_two="$(task_param user_two)"
group_a="$(task_param group_a)"
group_b="$(task_param group_b)"

groupadd "$group_a"
groupadd "$group_b"
usermod -aG "$group_a,$group_b" "$user_one"
usermod -aG "$group_a" "$user_two"
