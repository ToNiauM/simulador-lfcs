#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

address="$(task_param loopback_address)"

# New numbered netplan file dedicated to lo; existing files are left untouched.
cat > /etc/netplan/70-lfcs-loopback.yaml <<EOF
network:
  version: 2
  ethernets:
    lo:
      addresses: [$address]
EOF
chmod 600 /etc/netplan/70-lfcs-loopback.yaml
netplan apply
