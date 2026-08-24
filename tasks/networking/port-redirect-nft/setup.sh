#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

# nftables must be pre-installed in the guest image; never install from the Internet.
command -v nft >/dev/null 2>&1 || { echo "nftables is not installed in this guest image; bake it into the image (setup never downloads packages)" >&2; exit 69; }
nft list ruleset >/dev/null

table="$(task_param nft_table)"
# Idempotency: drop any leftover task table from a previous run in both families.
nft delete table ip "$table" 2>/dev/null || true
nft delete table inet "$table" 2>/dev/null || true

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/port-redirect-nft}" > /var/lib/lfcs-simulator/current-task
