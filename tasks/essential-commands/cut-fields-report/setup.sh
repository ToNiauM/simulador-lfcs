#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
source_file="$(task_param source_file)"
output_file="$(task_param output_file)"

mkdir -p "$work_dir"
task_param csv_content > "$work_dir/$source_file"
rm -f "$work_dir/$output_file"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/cut-fields-report}" > /var/lib/lfcs-simulator/current-task
