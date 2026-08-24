#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
immutable_file="$(task_param immutable_file)"
append_file="$(task_param append_file)"

chattr +i "$work_dir/$immutable_file"
chattr +a "$work_dir/$append_file"
