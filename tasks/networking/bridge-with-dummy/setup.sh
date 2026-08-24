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
command -v modprobe >/dev/null 2>&1 || { echo "kmod/modprobe is not installed in this guest image" >&2; exit 69; }
modinfo dummy >/dev/null 2>&1 || { echo "dummy kernel module unavailable in this guest image" >&2; exit 69; }

bridge="$(task_param bridge_name)"
dummy="$(task_param dummy_if)"

# Idempotency: remove leftovers from a previous run. Only the task-owned
# virtual interfaces (and NM profiles bound to them) are ever touched;
# never a physical NIC.
if [[ "$family" == rhel ]]; then
  while IFS= read -r uuid; do
    [[ -n "$uuid" ]] || continue
    ifname="$(nmcli -g connection.interface-name connection show uuid "$uuid" 2>/dev/null || true)"
    if [[ "$ifname" == "$bridge" || "$ifname" == "$dummy" ]]; then
      nmcli connection delete uuid "$uuid" >/dev/null 2>&1 || true
    fi
  done < <(nmcli -g UUID connection show 2>/dev/null || true)
fi
ip link del "$bridge" 2>/dev/null || true
ip link del "$dummy" 2>/dev/null || true

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/bridge-with-dummy}" > /var/lib/lfcs-simulator/current-task
