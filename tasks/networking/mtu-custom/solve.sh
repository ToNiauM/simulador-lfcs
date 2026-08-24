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

nic="$(task_param nic)"
mtu="$(task_param mtu)"

if [[ "$family" == debian ]]; then
  # New dedicated netplan file; never overwrite existing YAMLs.
  yaml="/etc/netplan/94-lfcs-mtu.yaml"
  cat > "$yaml" <<CONF
network:
  version: 2
  ethernets:
    ${nic}:
      dhcp4: false
      dhcp6: false
      mtu: ${mtu}
CONF
  chmod 600 "$yaml"
  netplan apply
else
  # New dedicated NetworkManager profile; existing connections stay untouched.
  # High autoconnect priority so this profile wins the device after reboot.
  con="lfcs-mtu-$nic"
  nmcli connection delete "$con" >/dev/null 2>&1 || true
  nmcli connection add type ethernet con-name "$con" ifname "$nic" \
    autoconnect yes connection.autoconnect-priority 999 \
    802-3-ethernet.mtu "$mtu" ipv4.method disabled ipv6.method disabled
  nmcli connection up "$con"
fi
ip link set dev "$nic" up
