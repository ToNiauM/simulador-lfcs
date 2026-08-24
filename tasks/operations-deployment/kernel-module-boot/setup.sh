#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

module="$(task_param module)"
load_file="$(task_param load_file)"
options_file="$(task_param options_file)"

# Start from a clean state: module unloaded, no persistence files.
modprobe -r "$module" 2>/dev/null || true
rm -f "$load_file" "$options_file"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/kernel-module-boot}" > /var/lib/lfcs-simulator/current-task
