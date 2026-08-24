#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

data_file="$(task_param data_file)"
report_file="$(task_param report_file)"

sort "$data_file" | uniq -c | sort -rn > "$report_file"
