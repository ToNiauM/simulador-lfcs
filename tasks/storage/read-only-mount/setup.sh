#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
[[ "$disk" == "/dev/vdb" && -b "$disk" ]] || { echo "expected disposable block device /dev/vdb" >&2; exit 65; }

# The task disk is exclusively owned by this disposable guest.
if pvs "$disk" &>/dev/null; then
  vg="$(pvs --noheadings -o vg_name "$disk" | xargs)"
  [[ -z "$vg" ]] || vgremove -ff -y "$vg"
  pvremove -ff -y "$disk" || true
fi
wipefs -af "$disk"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-storage/read-only-mount}" > /var/lib/lfcs-simulator/current-task
