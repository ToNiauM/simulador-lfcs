#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

# Idempotency: remove our previous persistent file, then force a runtime
# baseline that differs from every possible seeded target value.
rm -f /etc/sysctl.d/90-lfcs-net.conf
sysctl -w net.ipv4.tcp_syncookies=0 >/dev/null
sysctl -w net.core.somaxconn=128 >/dev/null
sysctl -w net.ipv4.tcp_fin_timeout=60 >/dev/null

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/network-sysctls}" > /var/lib/lfcs-simulator/current-task
