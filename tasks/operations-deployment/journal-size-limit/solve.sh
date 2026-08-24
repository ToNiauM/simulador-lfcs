#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

dropin_file="$(task_param dropin_file)"
max_use="$(task_param system_max_use)"
retention="$(task_param max_retention_sec)"

mkdir -p "$(dirname "$dropin_file")"
cat > "$dropin_file" <<CONF
[Journal]
SystemMaxUse=$max_use
MaxRetentionSec=$retention
CONF
systemctl restart systemd-journald
