#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

swap_file="$(task_param swap_file)"

# Ensure a clean slate: the target swap file must not exist yet.
if grep -q "^${swap_file} " /proc/swaps 2>/dev/null; then
  swapoff "$swap_file"
fi
rm -f "$swap_file"
sed -i "\\|^${swap_file}[[:space:]]|d" /etc/fstab

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/swap-file-persistent}" > /var/lib/lfcs-simulator/current-task
