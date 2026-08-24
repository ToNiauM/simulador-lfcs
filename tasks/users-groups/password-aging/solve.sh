#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
max_days="$(task_param max_days)"
min_days="$(task_param min_days)"
warn_days="$(task_param warn_days)"

chage -M "$max_days" -m "$min_days" -W "$warn_days" "$username"
