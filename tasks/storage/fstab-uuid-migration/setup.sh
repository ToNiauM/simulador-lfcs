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

size="$(task_param part_size_mib)"
fs="$(task_param filesystem)"
mount_point="$(task_param mount_point)"

sfdisk --wipe always "$disk" <<SF
label: gpt
,${size}MiB
SF
udevadm settle 2>/dev/null || true
part="${disk}1"
mkfs -t "$fs" -F "$part"
mkdir -p "$mount_point"
sed -i "\\|[[:space:]]$mount_point[[:space:]]|d" /etc/fstab
printf '%s %s %s defaults 0 2\n' "$part" "$mount_point" "$fs" >> /etc/fstab
mount "$mount_point"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-storage/fstab-uuid-migration}" > /var/lib/lfcs-simulator/current-task
