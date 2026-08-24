#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

program_path="$(task_param program_path)"
output_dir="$(task_param output_dir)"
stdout_file="$(task_param stdout_file)"
stderr_file="$(task_param stderr_file)"

mkdir -p "$output_dir"
"$program_path" > "$output_dir/$stdout_file" 2> "$output_dir/$stderr_file"
