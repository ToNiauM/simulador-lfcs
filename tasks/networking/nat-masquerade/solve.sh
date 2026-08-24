#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

subnet="$(task_param lan_subnet)"
wan="$(task_param wan_interface)"

# Active ruleset.
nft list table ip lfcs_nat >/dev/null 2>&1 && nft delete table ip lfcs_nat
nft add table ip lfcs_nat
nft 'add chain ip lfcs_nat postrouting { type nat hook postrouting priority 100 ; policy accept ; }'
nft add rule ip lfcs_nat postrouting ip saddr "$subnet" oifname "$wan" masquerade

# Persistence: dedicated file included from the family's boot-time nftables
# configuration, service enabled. Existing content is never destroyed.
. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro" >&2; exit 65 ;;
esac
nft list table ip lfcs_nat > /etc/nftables-lfcs.nft
if [[ "$family" == debian ]]; then
  conf=/etc/nftables.conf
  [[ -f "$conf" ]] || printf '#!/usr/sbin/nft -f\nflush ruleset\n' > "$conf"
else
  conf=/etc/sysconfig/nftables.conf
  [[ -f "$conf" ]] || : > "$conf"
fi
grep -qF '/etc/nftables-lfcs.nft' "$conf" || printf 'include "/etc/nftables-lfcs.nft"\n' >> "$conf"
systemctl enable nftables.service

# IPv4 forwarding, active and persistent.
printf 'net.ipv4.ip_forward = 1\n' > /etc/sysctl.d/99-lfcs-ipforward.conf
sysctl -w net.ipv4.ip_forward=1
