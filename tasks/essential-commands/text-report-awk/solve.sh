#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
data_file="$(task_param data_file)"
report_file="$(task_param report_file)"

awk '{ sum[$1] += $2; count[$1]++ }
END { for (category in sum) printf "%s %d %.2f\n", category, sum[category], sum[category] / count[category] }' \
  "$work_dir/$data_file" | sort > "$work_dir/$report_file"
