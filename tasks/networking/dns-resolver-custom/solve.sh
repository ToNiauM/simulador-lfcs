#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param lab_nic)"
dns1="$(task_param dns_server_1)"
dns2="$(task_param dns_server_2)"
search_domain="$(task_param search_domain)"
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
      nameservers:
        addresses:
          - ${dns1}
          - ${dns2}
        search:
          - ${search_domain}
EOF
  chmod 600 "$netplan_file"
  # Safe: the new YAML only references the secondary lab NIC.
  netplan apply
else
  # NetworkManager: add the resolvers to the connection that owns the lab NIC.
  con="$(nmcli -g GENERAL.CONNECTION device show "$nic" 2>/dev/null || true)"
  [[ -n "$con" && "$con" != "--" ]] || con="lfcs-lab-${nic}"
  nmcli con mod "$con" ipv4.dns "${dns1},${dns2}" ipv4.dns-search "$search_domain"
  nmcli con up "$con" >/dev/null
fi
