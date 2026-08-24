#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

acl_user="$(task_param acl_user)"
data_dir="$(task_param data_dir)"
mode="$(task_param dir_base_mode)"
file_a="$(task_param file_a)"
file_b="$(task_param file_b)"
token="$(task_param fixture_token)"

id "$acl_user" &>/dev/null || useradd -m -s /bin/bash "$acl_user"

rm -rf "$data_dir"
mkdir -p "$data_dir"
printf 'lfcs-fixture:%s:%s\n' "$token" "$file_a" > "$data_dir/$file_a"
printf 'lfcs-fixture:%s:%s\n' "$token" "$file_b" > "$data_dir/$file_b"
chown -R root:root "$data_dir"
chmod "$mode" "$data_dir"
chmod 640 "$data_dir/$file_a" "$data_dir/$file_b"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/acl-user-access}" > /var/lib/lfcs-simulator/current-task
