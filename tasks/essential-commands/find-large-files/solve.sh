#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

base="$(task_param base_dir)"
report="$(task_param report_file)"
threshold="$(task_param threshold_kib)"
age_days="$(task_param age_days)"

find "$base" -type f -size +"${threshold}k" -mtime +"$age_days" | LC_ALL=C sort > "$report"
