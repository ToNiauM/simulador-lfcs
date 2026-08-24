#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

port="$(task_param tcp_port)"

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro" >&2; exit 65 ;;
esac

# Accept-policy chain: never endangers the orchestrator's SSH session.
ruleset_snippet() {
  cat <<EOF
table inet lfcs_filter {
    chain input {
        type filter hook input priority 0; policy accept;
        tcp dport ${port} accept
    }
}
EOF
}

if [[ "$family" == debian ]]; then
  # Debian family: nftables.service loads /etc/nftables.conf.
  {
    printf '#!/usr/sbin/nft -f\n\nflush ruleset\n\n'
    ruleset_snippet
  } > /etc/nftables.conf
  load_file=/etc/nftables.conf
else
  # RHEL family: nftables.service loads /etc/sysconfig/nftables.conf.
  # Write a dedicated fragment and include it, keeping existing content intact.
  frag=/etc/nftables/lfcs-allow-port.nft
  mkdir -p /etc/nftables
  ruleset_snippet > "$frag"
  conf=/etc/sysconfig/nftables.conf
  [[ -f "$conf" ]] || : > "$conf"
  grep -qF "\"$frag\"" "$conf" || printf 'include "%s"\n' "$frag" >> "$conf"
  load_file="$frag"
fi

systemctl enable nftables >/dev/null 2>&1
nft delete table inet lfcs_filter 2>/dev/null || true
nft -f "$load_file"
