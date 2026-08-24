#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param lab_nic)"
netplan_file="$(task_param netplan_file)"

# Never touch the primary NIC: this task only uses the secondary lab NIC.
# If the guest does not expose it, create a persistent dummy device with the
# same name so the exercise still works and survives reboots.
if ! ip link show "$nic" &>/dev/null; then
  mkdir -p /etc/systemd/network
  printf '[NetDev]\nName=%s\nKind=dummy\n' "$nic" > "/etc/systemd/network/70-lfcs-${nic}.netdev"
  ip link add "$nic" type dummy
fi
ip link set "$nic" up
# Fresh start for this exercise: no addresses and no stale lab netplan file.
ip addr flush dev "$nic" || true
rm -f "$netplan_file"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/static-ip-secondary-nic}" > /var/lib/lfcs-simulator/current-task
