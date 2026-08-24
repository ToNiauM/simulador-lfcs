#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
immutable_file="$(task_param immutable_file)"
append_file="$(task_param append_file)"

mkdir -p "$work_dir"
# Clear any leftover attributes so fixtures can be rewritten deterministically.
for name in "$immutable_file" "$append_file"; do
  [[ -e "$work_dir/$name" ]] && chattr -ia "$work_dir/$name" || true
done
task_param immutable_content > "$work_dir/$immutable_file"
task_param append_content > "$work_dir/$append_file"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/file-attributes-immutable}" > /var/lib/lfcs-simulator/current-task
