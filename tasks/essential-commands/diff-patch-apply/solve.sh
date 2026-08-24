#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
patch_file="$(task_param patch_file)"

patch -d "$work_dir" -p1 < "$patch_file"
