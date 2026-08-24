#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param lab_nic)"
gateway="$(task_param gateway)"
dest_network="$(task_param dest_network)"
netplan_file="$(task_param netplan_file)"

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro: ${ID:-unknown}" >&2; exit 65 ;;
esac

if [[ "$family" == debian ]]; then
  # Own numbered netplan file, merged on top of the setup-provided one.
  cat > "$netplan_file" <<EOF
network:
  version: 2
  ethernets:
    ${nic}:
      routes:
        - to: ${dest_network}
          via: ${gateway}
EOF
  chmod 600 "$netplan_file"
  # Safe: the new YAML only references the secondary lab NIC.
  netplan apply
else
  # NetworkManager: add the route to the connection that owns the lab NIC.
  con="$(nmcli -g GENERAL.CONNECTION device show "$nic" 2>/dev/null || true)"
  [[ -n "$con" && "$con" != "--" ]] || con="lfcs-lab-${nic}"
  nmcli con mod "$con" ipv4.routes "${dest_network} ${gateway}"
  nmcli con up "$con" >/dev/null
fi
