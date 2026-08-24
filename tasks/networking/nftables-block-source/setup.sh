#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

command -v nft >/dev/null || { echo "nftables is required in the guest image" >&2; exit 65; }
subnet="$(task_param blocked_subnet)"

# Clean starting point: no pre-existing rule for the task subnet.
if nft list ruleset 2>/dev/null | grep -qF "$subnet"; then
  echo "guest already has rules for ${subnet}; expected a clean guest" >&2
  exit 65
fi

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/nftables-block-source}" > /var/lib/lfcs-simulator/current-task
