#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

command -v netplan >/dev/null 2>&1 || { echo "netplan is not installed in this guest image" >&2; exit 69; }

nic="$(task_param nic)"
vlan_iface="$(task_param vlan_iface)"
ip link show "$nic" >/dev/null 2>&1 || { echo "secondary NIC $nic not present in this guest; the task requires a second NIC" >&2; exit 69; }
# Idempotency: remove a leftover VLAN interface from a previous run.
# Only the task-owned VLAN interface is touched; never the NICs themselves.
ip link del "$vlan_iface" 2>/dev/null || true

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/vlan-interface}" > /var/lib/lfcs-simulator/current-task
