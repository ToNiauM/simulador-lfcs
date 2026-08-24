#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

log_file="$(task_param log_file)"
out_file="$(task_param out_file)"
level="$(task_param level)"

grep -E "^${level} " "$log_file" > "$out_file"
