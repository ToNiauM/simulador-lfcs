#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
[[ "$disk" == "/dev/vdb" && -b "$disk" ]] || { echo "expected disposable block device /dev/vdb" >&2; exit 65; }

# The task disk is exclusively owned by this disposable guest.
for md in /dev/md[0-9]* /dev/md/*; do
  [[ -b "$md" ]] || continue
  if mdadm --detail "$md" 2>/dev/null | grep -q "$disk"; then
    umount -f "$md" 2>/dev/null || true
    mdadm --stop "$md"
  fi
done
if pvs "$disk" &>/dev/null; then
  vg="$(pvs --noheadings -o vg_name "$disk" | xargs)"
  [[ -z "$vg" ]] || vgremove -ff -y "$vg"
  pvremove -ff -y "$disk" || true
fi
for part in "$disk"?*; do
  [[ -b "$part" ]] || continue
  mdadm --zero-superblock "$part" 2>/dev/null || true
done
wipefs -af "$disk"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-storage/mdadm-raid1}" > /var/lib/lfcs-simulator/current-task
