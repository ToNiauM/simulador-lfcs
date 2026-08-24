#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

user="$(task_param restricted_user)"
command="$(task_param forced_command)"

mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/60-lfcs-match.conf <<EOF
Match User $user
    ForceCommand $command
    AllowTcpForwarding no
EOF

/usr/sbin/sshd -t
systemctl reload-or-restart ssh.service 2>/dev/null || systemctl reload-or-restart sshd.service 2>/dev/null || true
