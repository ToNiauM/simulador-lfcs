#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

acl_user="$(task_param acl_user)"
data_dir="$(task_param data_dir)"
file_a="$(task_param file_a)"
file_b="$(task_param file_b)"

setfacl -m "u:${acl_user}:rwx" "$data_dir"
setfacl -d -m "u:${acl_user}:rwx" "$data_dir"
setfacl -m "u:${acl_user}:rw-" "$data_dir/$file_a" "$data_dir/$file_b"
