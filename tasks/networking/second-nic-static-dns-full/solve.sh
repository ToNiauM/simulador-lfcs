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
