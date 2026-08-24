#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
data_file="$(task_param data_file)"
report_file="$(task_param report_file)"

mkdir -p "$work_dir"
task_param data_content > "$work_dir/$data_file"
rm -f "$work_dir/$report_file"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/text-report-awk}" > /var/lib/lfcs-simulator/current-task
