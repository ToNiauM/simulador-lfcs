#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

nic="$(task_param lab_nic)"
lab_ip="$(task_param lab_ip)"
prefix_len="$(task_param prefix_len)"
setup_file="$(task_param setup_netplan_file)"
netplan_file="$(task_param netplan_file)"

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro: ${ID:-unknown}" >&2; exit 65 ;;
esac

# Never touch the primary NIC. Provide the lab NIC (dummy when the guest does
# not expose a second interface) plus its baseline static address, using the
# native mechanism of the detected family.
if [[ "$family" == debian ]]; then
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
else
  # NetworkManager baseline profile; recreating it also drops any route added
  # to it by a previous run, keeping setup idempotent.
  if ip link show "$nic" &>/dev/null; then
    ctype="$(nmcli -g GENERAL.TYPE device show "$nic" 2>/dev/null || true)"
    [[ -n "$ctype" ]] || ctype=ethernet
  else
    ctype=dummy
  fi
  nmcli con delete "lfcs-lab-${nic}" >/dev/null 2>&1 || true
  nmcli con add type "$ctype" ifname "$nic" con-name "lfcs-lab-${nic}" \
    connection.autoconnect yes ipv4.method manual \
    ipv4.addresses "${lab_ip}/${prefix_len}" ipv6.method disabled >/dev/null
  nmcli con up "lfcs-lab-${nic}" >/dev/null
  ip link set "$nic" up
  rm -f "$netplan_file"
fi

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/static-route-persistent}" > /var/lib/lfcs-simulator/current-task
