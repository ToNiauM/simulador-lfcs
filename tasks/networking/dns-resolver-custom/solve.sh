#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param lab_nic)"
dns1="$(task_param dns_server_1)"
dns2="$(task_param dns_server_2)"
search_domain="$(task_param search_domain)"
netplan_file="$(task_param netplan_file)"

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
