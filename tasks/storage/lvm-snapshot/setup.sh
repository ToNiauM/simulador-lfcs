#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
[[ "$disk" == "/dev/vdb" && -b "$disk" ]] || { echo "expected disposable block device /dev/vdb" >&2; exit 65; }

# The task disk is exclusively owned by this disposable guest.
for dev in "$disk" "$disk"[0-9]*; do
  [[ -b "$dev" ]] || continue
  swapoff "$dev" 2>/dev/null || true
  while IFS= read -r mounted_target; do
    [[ -z "$mounted_target" ]] || umount "$mounted_target"
  done < <(findmnt -rn -o TARGET -S "$dev" 2>/dev/null || true)
  if command -v pvs >/dev/null 2>&1 && pvs "$dev" &>/dev/null; then
    vg_owner="$(pvs --noheadings -o vg_name "$dev" | xargs)"
    [[ -z "$vg_owner" ]] || vgremove -ff -y "$vg_owner"
    pvremove -ff -y "$dev" || true
  fi
  [[ "$dev" == "$disk" ]] || wipefs -af "$dev" || true
done
wipefs -af "$disk"
blockdev --rereadpt "$disk" 2>/dev/null || true
udevadm settle 2>/dev/null || true

vg="$(task_param vg_name)"
origin="$(task_param origin_lv)"
origin_size="$(task_param origin_size_mib)"

pvcreate -ff -y "$disk"
vgcreate "$vg" "$disk"
lvcreate -y -L "${origin_size}M" -n "$origin" "$vg"
mkfs -t ext4 -F "/dev/$vg/$origin"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-storage/lvm-snapshot}" > /var/lib/lfcs-simulator/current-task
