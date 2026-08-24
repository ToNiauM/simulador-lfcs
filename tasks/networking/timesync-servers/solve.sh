#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

ntp1="$(task_param ntp_server_1)"
ntp2="$(task_param ntp_server_2)"
fallback="$(task_param fallback_server)"

mkdir -p /etc/systemd/timesyncd.conf.d
cat > /etc/systemd/timesyncd.conf.d/50-lfcs.conf <<EOF
[Time]
NTP=$ntp1 $ntp2
FallbackNTP=$fallback
EOF

systemctl enable systemd-timesyncd.service
systemctl restart systemd-timesyncd.service
