#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
patch_file="$(task_param patch_file)"
conf_name="$(task_param conf_name)"
notes_name="$(task_param notes_name)"
keep_name="$(task_param keep_name)"

rm -rf "$work_dir"
mkdir -p "$work_dir" "$(dirname "$patch_file")"
task_param conf_content > "$work_dir/$conf_name"
task_param notes_content > "$work_dir/$notes_name"
task_param keep_content > "$work_dir/$keep_name"
task_param patch_text > "$patch_file"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/diff-patch-apply}" > /var/lib/lfcs-simulator/current-task
