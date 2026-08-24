#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

port="$(task_param tcp_port)"

# Accept-policy chain: never endangers the orchestrator's SSH session.
cat > /etc/nftables.conf <<EOF
#!/usr/sbin/nft -f

flush ruleset

table inet lfcs_filter {
    chain input {
        type filter hook input priority 0; policy accept;
        tcp dport ${port} accept
    }
}
EOF
systemctl enable nftables >/dev/null 2>&1
nft -f /etc/nftables.conf
