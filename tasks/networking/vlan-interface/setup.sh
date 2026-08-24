#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro family" >&2; exit 65 ;;
esac

if [[ "$family" == debian ]]; then
  command -v netplan >/dev/null 2>&1 || { echo "netplan is not installed in this guest image" >&2; exit 69; }
else
  command -v nmcli >/dev/null 2>&1 || { echo "NetworkManager (nmcli) is not installed in this guest image" >&2; exit 69; }
fi

nic="$(task_param nic)"
vlan_iface="$(task_param vlan_iface)"
ip link show "$nic" >/dev/null 2>&1 || { echo "secondary NIC $nic not present in this guest; the task requires a second NIC" >&2; exit 69; }

# Idempotency: remove a leftover VLAN interface (and any NM profile bound to
# it) from a previous run. Only the task-owned VLAN interface is touched;
# never the NICs themselves.
if [[ "$family" == rhel ]]; then
  while IFS= read -r uuid; do
    [[ -n "$uuid" ]] || continue
    ifname="$(nmcli -g connection.interface-name connection show uuid "$uuid" 2>/dev/null || true)"
    if [[ "$ifname" == "$vlan_iface" ]]; then
      nmcli connection delete uuid "$uuid" >/dev/null 2>&1 || true
    fi
  done < <(nmcli -g UUID connection show 2>/dev/null || true)
fi
ip link del "$vlan_iface" 2>/dev/null || true

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/vlan-interface}" > /var/lib/lfcs-simulator/current-task
