#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param nic)"
mtu="$(task_param mtu)"

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
ip link set dev "$nic" up
