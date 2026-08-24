#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
gzip_file="$(task_param gzip_file)"
xz_file="$(task_param xz_file)"

gzip -k "$work_dir/$gzip_file"
xz -k "$work_dir/$xz_file"
