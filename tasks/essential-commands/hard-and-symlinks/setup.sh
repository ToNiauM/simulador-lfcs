#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
hard_target="$(task_param hard_target)"
sym_target="$(task_param sym_target)"
token="$(task_param fixture_token)"

rm -rf "$work_dir"
mkdir -p "$work_dir/data" "$work_dir/backup" "$work_dir/releases"

printf 'lfcs-fixture:%s:hard-target\n' "$token" > "$hard_target"
printf 'lfcs-fixture:%s:sym-target\n' "$token" > "$sym_target"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/hard-and-symlinks}" > /var/lib/lfcs-simulator/current-task
