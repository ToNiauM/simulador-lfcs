#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

src="$(task_param source_dir)"
sentinel="$(task_param sentinel_file)"
content="$(task_param sentinel_content)"

mkdir -p "$src"
printf '%s\n' "$content" > "$src/$sentinel"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-storage/bind-mount-persistent}" > /var/lib/lfcs-simulator/current-task
