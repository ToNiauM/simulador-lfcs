#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

subnet="$(task_param blocked_subnet)"

# Accept-policy chain plus one targeted drop: the orchestrator's SSH session
# comes from outside the documentation range, so it is never affected.
cat > /etc/nftables.conf <<EOF
#!/usr/sbin/nft -f

flush ruleset

table inet lfcs_filter {
    chain input {
        type filter hook input priority 0; policy accept;
        ip saddr ${subnet} drop
    }
}
EOF
systemctl enable nftables >/dev/null 2>&1
nft -f /etc/nftables.conf
