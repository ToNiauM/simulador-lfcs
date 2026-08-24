#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
prefix="$(task_param prefix)"
old_ext="$(task_param old_ext)"
new_ext="$(task_param new_ext)"

for file in "$work_dir/$prefix"-*."$old_ext"; do
  [[ -e "$file" ]] || continue
  mv "$file" "${file%."$old_ext"}.$new_ext"
done
