#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

data_dir="$(task_param data_dir)"
archive="$(task_param archive_path)"
exclude="$(task_param exclude_glob)"

tar --exclude="$exclude" -czf "$archive" -C "$(dirname "$data_dir")" "$(basename "$data_dir")"
