#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

iface="$(task_param interface)"
address="$(task_param address)"
route_to="$(task_param route_to)"
route_via="$(task_param route_via)"
dns1="$(task_param dns_1)"
dns2="$(task_param dns_2)"
domain="$(task_param search_domain)"

# Never touch the interface that carries the default route.
default_dev="$(ip -j route show default | python3 -c 'import json,sys; routes=json.load(sys.stdin); print(routes[0].get("dev","") if routes else "")')"
[[ "$default_dev" != "$iface" ]] || { echo "refusing to touch primary interface $iface" >&2; exit 65; }

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro: ${ID:-unknown}" >&2; exit 65 ;;
esac

if [[ "$family" == debian ]]; then
  # Single new numbered netplan file; existing files are left untouched.
  cat > /etc/netplan/80-lfcs-static.yaml <<EOF
network:
  version: 2
  ethernets:
    $iface:
      dhcp4: false
      optional: true
      addresses: [$address]
      routes:
        - to: $route_to
          via: $route_via
          on-link: true
      nameservers:
        addresses: [$dns1, $dns2]
        search: [$domain]
EOF
  chmod 600 /etc/netplan/80-lfcs-static.yaml
  netplan apply
else
  # NetworkManager: single new profile bound to the secondary NIC.
  ctype="$(nmcli -g GENERAL.TYPE device show "$iface" 2>/dev/null || true)"
  [[ -n "$ctype" ]] || ctype=ethernet
  nmcli con delete lfcs-static >/dev/null 2>&1 || true
  nmcli con add type "$ctype" ifname "$iface" con-name lfcs-static \
    connection.autoconnect yes connection.autoconnect-priority 10 \
    ipv4.method manual ipv4.addresses "$address" \
    ipv4.routes "${route_to} ${route_via}" \
    ipv4.dns "${dns1},${dns2}" ipv4.dns-search "$domain" \
    ipv6.method disabled >/dev/null
  nmcli con up lfcs-static >/dev/null
fi
