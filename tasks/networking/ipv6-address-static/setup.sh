#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro: ${ID:-unknown}" >&2; exit 65 ;;
esac

if [[ "$family" == debian ]]; then
  command -v netplan >/dev/null 2>&1 || { echo "netplan is not installed in this guest image" >&2; exit 69; }
else
  command -v nmcli >/dev/null 2>&1 || { echo "NetworkManager (nmcli) is not installed in this guest image" >&2; exit 69; }
fi

nic="$(task_param nic)"
ip link show "$nic" >/dev/null 2>&1 || { echo "secondary NIC $nic not present in this guest; the task requires a second NIC" >&2; exit 69; }
# Never touch the primary interface: this pack only ever configures $nic.

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/ipv6-address-static}" > /var/lib/lfcs-simulator/current-task
