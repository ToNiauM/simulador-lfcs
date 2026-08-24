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

# Persistence: family-specific boot-time nftables configuration. Never
# rewrite the distro file, only append.
. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro" >&2; exit 65 ;;
esac

table_snippet() {
  cat <<NFT

table ip ${table} {
	chain prerouting {
		type nat hook prerouting priority -100; policy accept;
		tcp dport ${src_port} redirect to :${dst_port}
	}
}
NFT
}

if [[ "$family" == debian ]]; then
  # Debian family: nftables.service loads /etc/nftables.conf.
  conf=/etc/nftables.conf
  [[ -f "$conf" ]] || printf '#!/usr/sbin/nft -f\nflush ruleset\n' > "$conf"
  grep -q "table ip $table" "$conf" || table_snippet >> "$conf"
  nft -c -f "$conf"
else
  # RHEL family: nftables.service loads /etc/sysconfig/nftables.conf.
  # Dedicated fragment included from it, keeping existing content intact.
  frag=/etc/nftables/lfcs-port-redirect.nft
  mkdir -p /etc/nftables
  table_snippet > "$frag"
  conf=/etc/sysconfig/nftables.conf
  [[ -f "$conf" ]] || : > "$conf"
  grep -qF "\"$frag\"" "$conf" || printf 'include "%s"\n' "$frag" >> "$conf"
  nft -c -f "$frag"
fi
systemctl enable nftables.service
