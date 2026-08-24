#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param lab_nic)"
ip_address="$(task_param ip_address)"
prefix_len="$(task_param prefix_len)"
netplan_file="$(task_param netplan_file)"

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro: ${ID:-unknown}" >&2; exit 65 ;;
esac

if [[ "$family" == debian ]]; then
  # Own numbered netplan file: never overwrite the system-provided YAML.
  cat > "$netplan_file" <<EOF
network:
  version: 2
  ethernets:
    ${nic}:
      dhcp4: false
      addresses:
        - ${ip_address}/${prefix_len}
EOF
  chmod 600 "$netplan_file"
  # Safe: the new YAML only references the secondary lab NIC.
  netplan apply
else
  # NetworkManager: own profile bound to the lab NIC, matching the device type
  # (dummy when setup created the interface, ethernet for a real second NIC).
  ctype="$(nmcli -g GENERAL.TYPE device show "$nic" 2>/dev/null || true)"
  [[ -n "$ctype" ]] || ctype=ethernet
  nmcli con delete "lfcs-${nic}" >/dev/null 2>&1 || true
  nmcli con add type "$ctype" ifname "$nic" con-name "lfcs-${nic}" \
    connection.autoconnect yes connection.autoconnect-priority 10 \
    ipv4.method manual ipv4.addresses "${ip_address}/${prefix_len}" ipv6.method disabled >/dev/null
  nmcli con up "lfcs-${nic}" >/dev/null
fi
