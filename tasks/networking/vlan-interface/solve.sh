#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param nic)"
vlan_id="$(task_param vlan_id)"
vlan_iface="$(task_param vlan_iface)"
vlan_ip="$(task_param vlan_ip)"

# New dedicated netplan file; never overwrite existing YAMLs. The parent NIC
# is declared only so netplan can reference it as the VLAN link; the primary
# interface is never touched.
yaml="/etc/netplan/93-lfcs-vlan.yaml"
cat > "$yaml" <<CONF
network:
  version: 2
  ethernets:
    ${nic}:
      dhcp4: false
      dhcp6: false
  vlans:
    ${vlan_iface}:
      id: ${vlan_id}
      link: ${nic}
      addresses:
        - "${vlan_ip}"
CONF
chmod 600 "$yaml"
netplan apply
