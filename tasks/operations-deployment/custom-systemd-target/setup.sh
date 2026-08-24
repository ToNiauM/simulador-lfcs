#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

target="$(task_param target_name)"
svc_a="$(task_param service_a)"
svc_b="$(task_param service_b)"

for svc in "$svc_a" "$svc_b"; do
  cat > "/etc/systemd/system/$svc" <<UNIT
[Unit]
Description=LFCS lab service $svc

[Service]
Type=oneshot
ExecStart=/bin/true
RemainAfterExit=yes
UNIT
done

# Guarantee a clean slate for the target the candidate must create.
rm -f "/etc/systemd/system/$target"
rm -rf "/etc/systemd/system/${target}.wants"
systemctl daemon-reload

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/custom-systemd-target}" > /var/lib/lfcs-simulator/current-task
