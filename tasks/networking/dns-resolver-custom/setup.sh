#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param lab_nic)"
lab_ip="$(task_param lab_ip)"
prefix_len="$(task_param prefix_len)"
setup_file="$(task_param setup_netplan_file)"
netplan_file="$(task_param netplan_file)"

# Never touch the primary NIC. Create a persistent dummy device with the lab
# NIC name when the guest does not expose a second interface.
if ! ip link show "$nic" &>/dev/null; then
  mkdir -p /etc/systemd/network
  printf '[NetDev]\nName=%s\nKind=dummy\n' "$nic" > "/etc/systemd/network/70-lfcs-${nic}.netdev"
  ip link add "$nic" type dummy
fi
ip link set "$nic" up
rm -f "$netplan_file"

# Baseline addressing for the lab NIC, owned by setup (own numbered file).
cat > "$setup_file" <<EOF
network:
  version: 2
  ethernets:
    ${nic}:
      dhcp4: false
      addresses:
        - ${lab_ip}/${prefix_len}
EOF
chmod 600 "$setup_file"
# Safe: this YAML only references the secondary lab NIC.
netplan apply

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/dns-resolver-custom}" > /var/lib/lfcs-simulator/current-task
