#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

iface="$(task_param interface)"
domain1="$(task_param search_domain_1)"
domain2="$(task_param search_domain_2)"

# New numbered netplan file; existing files are left untouched.
cat > /etc/netplan/60-lfcs-search.yaml <<EOF
network:
  version: 2
  ethernets:
    $iface:
      dhcp4: false
      optional: true
      nameservers:
        search: [$domain1, $domain2]
EOF
chmod 600 /etc/netplan/60-lfcs-search.yaml
netplan apply
