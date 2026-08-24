#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param lab_nic)"
netplan_file="$(task_param netplan_file)"

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro: ${ID:-unknown}" >&2; exit 65 ;;
esac

# Fresh start on RHEL-family guests: drop any stale reference-solution profile
# before probing the device (deleting an active dummy profile removes the link).
if [[ "$family" == rhel ]]; then
  nmcli con delete "lfcs-${nic}" >/dev/null 2>&1 || true
fi

# Never touch the primary NIC: this task only uses the secondary lab NIC.
# If the guest does not expose it, create a persistent dummy device with the
# same name so the exercise still works and survives reboots.
if ! ip link show "$nic" &>/dev/null; then
  if [[ "$family" == debian ]]; then
    mkdir -p /etc/systemd/network
    printf '[NetDev]\nName=%s\nKind=dummy\n' "$nic" > "/etc/systemd/network/70-lfcs-${nic}.netdev"
    ip link add "$nic" type dummy
  else
    nmcli con delete "lfcs-lab-${nic}" >/dev/null 2>&1 || true
    nmcli con add type dummy ifname "$nic" con-name "lfcs-lab-${nic}" \
      connection.autoconnect yes ipv4.method disabled ipv6.method disabled >/dev/null
    nmcli con up "lfcs-lab-${nic}" >/dev/null
  fi
fi
ip link set "$nic" up
# Fresh start for this exercise: no addresses and no stale lab netplan file.
ip addr flush dev "$nic" || true
rm -f "$netplan_file"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/static-ip-secondary-nic}" > /var/lib/lfcs-simulator/current-task
