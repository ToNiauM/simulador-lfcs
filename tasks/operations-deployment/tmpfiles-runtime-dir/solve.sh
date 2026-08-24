#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

runtime_dir="$(task_param runtime_dir)"
owner="$(task_param dir_owner)"
group="$(task_param dir_group)"
mode="$(task_param dir_mode)"

conf="/etc/tmpfiles.d/$(basename "$runtime_dir").conf"
printf 'd %s %s %s %s -\n' "$runtime_dir" "$mode" "$owner" "$group" > "$conf"
systemd-tmpfiles --create "$conf"
