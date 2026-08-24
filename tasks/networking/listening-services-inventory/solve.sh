#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

report_path="$(task_param report_path)"
ss -H -tln | awk '{print $4}' | sed 's/.*://' | sort -n -u > "$report_path"
