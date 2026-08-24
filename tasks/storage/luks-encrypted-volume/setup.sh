#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
mapper="$(task_param mapper_name)"
[[ "$disk" == "/dev/vdb" && -b "$disk" ]] || { echo "expected disposable block device /dev/vdb" >&2; exit 65; }

# The task disk is exclusively owned by this disposable guest.
if [[ -e "/dev/mapper/$mapper" ]]; then
  umount -f "/dev/mapper/$mapper" 2>/dev/null || true
  cryptsetup close "$mapper" || true
fi
if pvs "$disk" &>/dev/null; then
  vg="$(pvs --noheadings -o vg_name "$disk" | xargs)"
  [[ -z "$vg" ]] || vgremove -ff -y "$vg"
  pvremove -ff -y "$disk" || true
fi
wipefs -af "$disk"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-storage/luks-encrypted-volume}" > /var/lib/lfcs-simulator/current-task
