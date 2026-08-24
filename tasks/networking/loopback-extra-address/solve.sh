#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro family" >&2; exit 65 ;;
esac

address="$(task_param loopback_address)"

if [[ "$family" == debian ]]; then
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
else
  # NetworkManager loopback connection (supported since NM 1.42, RHEL 9).
  # 127.0.0.1/8 is listed explicitly so the base loopback address is kept.
  nmcli connection delete lfcs-loopback >/dev/null 2>&1 || true
  nmcli connection add type loopback con-name lfcs-loopback ifname lo \
    autoconnect yes ipv4.method manual ipv4.addresses "127.0.0.1/8,$address"
  nmcli connection up lfcs-loopback
fi
