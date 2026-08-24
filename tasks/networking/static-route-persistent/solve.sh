#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param lab_nic)"
gateway="$(task_param gateway)"
dest_network="$(task_param dest_network)"
netplan_file="$(task_param netplan_file)"

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
