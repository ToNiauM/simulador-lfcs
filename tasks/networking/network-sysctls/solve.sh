#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

syncookies="$(task_param tcp_syncookies)"
somaxconn="$(task_param somaxconn)"
fin_timeout="$(task_param tcp_fin_timeout)"

cat > /etc/sysctl.d/90-lfcs-net.conf <<EOF
net.ipv4.tcp_syncookies = $syncookies
net.core.somaxconn = $somaxconn
net.ipv4.tcp_fin_timeout = $fin_timeout
EOF

sysctl -w "net.ipv4.tcp_syncookies=$syncookies" >/dev/null
sysctl -w "net.core.somaxconn=$somaxconn" >/dev/null
sysctl -w "net.ipv4.tcp_fin_timeout=$fin_timeout" >/dev/null
