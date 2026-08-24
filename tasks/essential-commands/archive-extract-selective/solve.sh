#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

archive="$(task_param archive_path)"
dest_dir="$(task_param dest_dir)"
app="$(task_param app_name)"
subdir="$(task_param wanted_subdir)"

mkdir -p "$dest_dir"
tar -xzf "$archive" -C "$dest_dir" "$app/$subdir"
