#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

svc_mask="$(task_param service_mask)"
svc_disable="$(task_param service_disable)"

for svc in "$svc_mask" "$svc_disable"; do
  # Remove any leftover mask before (re)installing the unit.
  systemctl unmask "$svc" >/dev/null 2>&1 || true
  cat > "/etc/systemd/system/$svc" <<UNIT
[Unit]
Description=LFCS lab service $svc

[Service]
Type=simple
ExecStart=/bin/sleep infinity

[Install]
WantedBy=multi-user.target
UNIT
done
systemctl daemon-reload
systemctl enable --now "$svc_mask" "$svc_disable"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/mask-disable-service}" > /var/lib/lfcs-simulator/current-task
