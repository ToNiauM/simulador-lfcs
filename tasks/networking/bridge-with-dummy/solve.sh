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

bridge="$(task_param bridge_name)"
dummy="$(task_param dummy_if)"
bridge_ip="$(task_param bridge_ip)"

# Load the dummy module now and at every boot (required by the statement on
# both families, even though NetworkManager can create dummy links itself).
printf 'dummy\n' > /etc/modules-load.d/lfcs-dummy.conf
modprobe dummy

if [[ "$family" == debian ]]; then
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
else
  # New dedicated NetworkManager profiles; existing connections stay untouched.
  nmcli connection add type bridge ifname "$bridge" con-name "lfcs-$bridge" \
    autoconnect yes bridge.stp no \
    ipv4.method manual ipv4.addresses "$bridge_ip" ipv6.method disabled
  nmcli connection add type dummy ifname "$dummy" con-name "lfcs-$dummy" \
    autoconnect yes connection.master "$bridge" connection.slave-type bridge
  nmcli connection up "lfcs-$bridge"
  nmcli connection up "lfcs-$dummy"
fi
