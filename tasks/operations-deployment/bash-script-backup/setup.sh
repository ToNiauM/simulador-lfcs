#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

script_path="$(task_param script_path)"
source_dir="$(task_param source_dir)"
data_token="$(task_param data_token)"

# Ensure a clean slate and a deterministic fixture directory.
rm -f "$script_path"
rm -rf "$source_dir"
mkdir -p "$source_dir/logs"
printf 'report %s\nline two of the report\n' "$data_token" > "$source_dir/report.txt"
printf 'id,value\n1,%s\n2,%s\n' "${data_token:0:8}" "${data_token:8:8}" > "$source_dir/data.csv"
printf 'entry %s\n' "$data_token" > "$source_dir/logs/notes.log"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/bash-script-backup}" > /var/lib/lfcs-simulator/current-task
