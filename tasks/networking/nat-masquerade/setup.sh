#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

# Idempotency: remove artifacts from a previous run of this pack, then make
# sure forwarding starts disabled so the task actually has work to do.
nft list table ip lfcs_nat >/dev/null 2>&1 && nft delete table ip lfcs_nat
rm -f /etc/nftables-lfcs.nft /etc/sysctl.d/99-lfcs-ipforward.conf
if [[ -f /etc/nftables.conf ]]; then
  sed -i '\|/etc/nftables-lfcs\.nft|d' /etc/nftables.conf
fi
echo 0 > /proc/sys/net/ipv4/ip_forward

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/nat-masquerade}" > /var/lib/lfcs-simulator/current-task
