#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

permit_root="$(task_param permit_root_login)"
match_user="$(task_param match_user)"

# Low-numbered drop-in so its global directives are obtained first
# (sshd honours the first value seen for a keyword).
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/05-lfcs-harden.conf <<EOF
PermitRootLogin ${permit_root}
Match User ${match_user}
    PasswordAuthentication no
EOF
/usr/sbin/sshd -t
systemctl restart ssh.service 2>/dev/null || systemctl restart sshd.service 2>/dev/null || true
