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

# Persistence: dedicated file included from /etc/nftables.conf, service enabled.
nft list table ip lfcs_nat > /etc/nftables-lfcs.nft
if [[ ! -f /etc/nftables.conf ]]; then
  printf '#!/usr/sbin/nft -f\nflush ruleset\n' > /etc/nftables.conf
fi
grep -qF '/etc/nftables-lfcs.nft' /etc/nftables.conf || printf 'include "/etc/nftables-lfcs.nft"\n' >> /etc/nftables.conf
systemctl enable nftables.service

# IPv4 forwarding, active and persistent.
printf 'net.ipv4.ip_forward = 1\n' > /etc/sysctl.d/99-lfcs-ipforward.conf
sysctl -w net.ipv4.ip_forward=1
