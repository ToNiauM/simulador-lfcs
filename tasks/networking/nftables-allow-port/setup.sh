#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

command -v nft >/dev/null || { echo "nftables is required in the guest image" >&2; exit 65; }
port="$(task_param tcp_port)"

# Clean starting point: no pre-existing accept rule for the task port.
if nft list ruleset 2>/dev/null | grep -q "dport ${port}"; then
  echo "guest already has rules for port ${port}; expected a clean guest" >&2
  exit 65
fi

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/nftables-allow-port}" > /var/lib/lfcs-simulator/current-task
