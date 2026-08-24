#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
gzip_file="$(task_param gzip_file)"
xz_file="$(task_param xz_file)"

mkdir -p "$work_dir"
task_param gzip_content > "$work_dir/$gzip_file"
task_param xz_content > "$work_dir/$xz_file"
rm -f "$work_dir/$gzip_file.gz" "$work_dir/$xz_file.xz"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/compress-multiple-formats}" > /var/lib/lfcs-simulator/current-task
