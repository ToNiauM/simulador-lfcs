#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

bridge="$(task_param bridge_name)"
dummy="$(task_param dummy_if)"
bridge_ip="$(task_param bridge_ip)"

# Load the dummy module now and at every boot.
printf 'dummy\n' > /etc/modules-load.d/lfcs-dummy.conf
modprobe dummy

# New dedicated netplan file; never overwrite existing YAMLs.
yaml="/etc/netplan/92-lfcs-bridge-dummy.yaml"
cat > "$yaml" <<CONF
network:
  version: 2
  dummy-devices:
    ${dummy}: {}
  bridges:
    ${bridge}:
      interfaces: [${dummy}]
      addresses:
        - "${bridge_ip}"
CONF
chmod 600 "$yaml"
netplan apply
