#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param lab_nic)"
ip_address="$(task_param ip_address)"
prefix_len="$(task_param prefix_len)"
netplan_file="$(task_param netplan_file)"

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
