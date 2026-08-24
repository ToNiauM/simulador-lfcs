#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

app="$(task_param app_name)"
log_path="$(task_param log_path)"
rotate="$(task_param rotate_count)"
mode="$(task_param create_mode)"
owner="$(task_param create_user)"
group="$(task_param create_group)"

cat > "/etc/logrotate.d/$app" <<EOF
$log_path {
    weekly
    rotate $rotate
    compress
    create $mode $owner $group
}
EOF
