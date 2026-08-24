#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

command -v netplan >/dev/null 2>&1 || { echo "netplan is not installed in this guest image" >&2; exit 69; }
command -v modprobe >/dev/null 2>&1 || { echo "kmod/modprobe is not installed in this guest image" >&2; exit 69; }
modinfo dummy >/dev/null 2>&1 || { echo "dummy kernel module unavailable in this guest image" >&2; exit 69; }

bridge="$(task_param bridge_name)"
dummy="$(task_param dummy_if)"
# Idempotency: remove any leftover interfaces from a previous run. Only the
# task-owned virtual interfaces are ever touched; never a physical NIC.
ip link del "$bridge" 2>/dev/null || true
ip link del "$dummy" 2>/dev/null || true

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/bridge-with-dummy}" > /var/lib/lfcs-simulator/current-task
