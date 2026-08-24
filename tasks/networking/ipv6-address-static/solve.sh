#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param nic)"
address="$(task_param ipv6_address)"

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro: ${ID:-unknown}" >&2; exit 65 ;;
esac

if [[ "$family" == debian ]]; then
  # New dedicated netplan file; never overwrite existing YAMLs.
  yaml="/etc/netplan/91-lfcs-ipv6-static.yaml"
  cat > "$yaml" <<CONF
network:
  version: 2
  ethernets:
    ${nic}:
      dhcp4: false
      dhcp6: false
      accept-ra: false
      addresses:
        - "${address}"
CONF
  chmod 600 "$yaml"
  netplan apply
else
  # NetworkManager: own profile bound to the NIC, matching the device type.
  ctype="$(nmcli -g GENERAL.TYPE device show "$nic" 2>/dev/null || true)"
  [[ -n "$ctype" ]] || ctype=ethernet
  nmcli con delete lfcs-ipv6-static >/dev/null 2>&1 || true
  nmcli con add type "$ctype" ifname "$nic" con-name lfcs-ipv6-static \
    connection.autoconnect yes connection.autoconnect-priority 10 \
    ipv4.method disabled ipv6.method manual ipv6.addresses "$address" >/dev/null
  nmcli con up lfcs-ipv6-static >/dev/null
fi
