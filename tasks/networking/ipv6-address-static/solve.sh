#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param nic)"
address="$(task_param ipv6_address)"

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
