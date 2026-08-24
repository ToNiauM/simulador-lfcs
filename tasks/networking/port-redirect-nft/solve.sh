#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

table="$(task_param nft_table)"
src_port="$(task_param src_port)"
dst_port="$(task_param dst_port)"

# Live ruleset.
nft add table ip "$table"
nft -- add chain ip "$table" prerouting '{ type nat hook prerouting priority -100 ; policy accept ; }'
nft add rule ip "$table" prerouting tcp dport "$src_port" redirect to :"$dst_port"

# Persistence: append the task table to /etc/nftables.conf (loaded by
# nftables.service at boot). Never rewrite the distro file, only append.
conf=/etc/nftables.conf
[[ -f "$conf" ]] || printf '#!/usr/sbin/nft -f\nflush ruleset\n' > "$conf"
if ! grep -q "table ip $table" "$conf"; then
  cat >> "$conf" <<NFT

table ip ${table} {
	chain prerouting {
		type nat hook prerouting priority -100; policy accept;
		tcp dport ${src_port} redirect to :${dst_port}
	}
}
NFT
fi
nft -c -f "$conf"
systemctl enable nftables.service
