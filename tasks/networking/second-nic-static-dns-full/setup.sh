#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

iface="$(task_param interface)"
address="$(task_param address)"
route_to="$(task_param route_to)"

# Never touch the interface that carries the default route.
default_dev="$(ip -j route show default | python3 -c 'import json,sys; routes=json.load(sys.stdin); print(routes[0].get("dev","") if routes else "")')"
[[ "$default_dev" != "$iface" ]] || { echo "refusing to touch primary interface $iface" >&2; exit 65; }
ip link show "$iface" >/dev/null

# Idempotency: drop any previous configuration of ours that references the
# seeded address, whichever mechanism produced it, then clean runtime state.
plain_ip="${address%%/*}"
if command -v nmcli >/dev/null 2>&1; then
  nmcli con delete lfcs-static >/dev/null 2>&1 || true
fi
while IFS= read -r conf; do
  rm -f "$conf"
done < <(grep -l -- "$plain_ip" /etc/netplan/*.yaml /etc/netplan/*.yml \
  /etc/systemd/network/*.network /etc/NetworkManager/system-connections/* 2>/dev/null || true)
if command -v nmcli >/dev/null 2>&1; then
  nmcli con reload >/dev/null 2>&1 || true
fi
ip route del "$route_to" 2>/dev/null || true
ip -4 addr flush dev "$iface" 2>/dev/null || true

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/second-nic-static-dns-full}" > /var/lib/lfcs-simulator/current-task
