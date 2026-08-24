#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

address="$(task_param loopback_address)"

# Idempotency: drop the runtime address and any previous persistent config of
# ours that references it (netplan, systemd-networkd or NetworkManager).
ip addr del "$address" dev lo 2>/dev/null || true
plain_ip="${address%%/*}"
while IFS= read -r conf; do
  rm -f "$conf"
done < <(grep -l -- "$plain_ip" /etc/netplan/*.yaml /etc/netplan/*.yml /etc/systemd/network/*.network /etc/NetworkManager/system-connections/* 2>/dev/null || true)
if command -v nmcli >/dev/null 2>&1; then
  nmcli connection reload >/dev/null 2>&1 || true
fi

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/loopback-extra-address}" > /var/lib/lfcs-simulator/current-task
