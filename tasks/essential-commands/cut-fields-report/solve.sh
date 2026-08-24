#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
source_file="$(task_param source_file)"
output_file="$(task_param output_file)"
delimiter="$(task_param delimiter)"
fields="$(task_param fields)"

cut -d "$delimiter" -f "$fields" "$work_dir/$source_file" > "$work_dir/$output_file"
