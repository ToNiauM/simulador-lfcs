#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

command -v rsyslogd >/dev/null || { echo "rsyslog is required for this task but is not installed; refusing to continue (network installs are forbidden in the lab)" >&2; exit 69; }

conf_file="$(task_param conf_file)"
log_file="$(task_param log_file)"

# Clean slate: the candidate must create the rule and produce the log file.
rm -f "$conf_file" "$log_file"
systemctl restart rsyslog

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/rsyslog-custom-facility}" > /var/lib/lfcs-simulator/current-task
