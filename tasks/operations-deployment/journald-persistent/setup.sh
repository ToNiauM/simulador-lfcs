#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

dropin="$(task_param dropin_file)"

# Start from a volatile journal: no persistent directory and an explicit
# baseline forcing volatile storage (a later drop-in overrides it).
rm -f "$dropin"
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/00-lfcs-baseline.conf <<'EOF'
[Journal]
Storage=volatile
EOF
rm -rf /var/log/journal
systemctl restart systemd-journald

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/journald-persistent}" > /var/lib/lfcs-simulator/current-task
