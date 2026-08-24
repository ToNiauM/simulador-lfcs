#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
vg="$(task_param vg_name)"
lv="$(task_param lv_name)"
initial="$(task_param initial_size_mib)"
fs="$(task_param filesystem)"
mount_point="$(task_param mount_point)"
[[ "$disk" == "/dev/vdb" && -b "$disk" ]] || { echo "expected disposable block device /dev/vdb" >&2; exit 65; }

# The task disk is exclusively owned by this disposable guest.
if pvs "$disk" &>/dev/null; then
  old_vg="$(pvs --noheadings -o vg_name "$disk" | xargs)"
  [[ -z "$old_vg" ]] || vgremove -ff -y "$old_vg"
  pvremove -ff -y "$disk" || true
fi
wipefs -af "$disk"

pvcreate -ff -y "$disk"
vgcreate "$vg" "$disk"
lvcreate -y -L "${initial}M" -n "$lv" "$vg"
mkfs.xfs -f "/dev/$vg/$lv"
mkdir -p "$mount_point"
uuid="$(blkid -s UUID -o value "/dev/$vg/$lv")"
sed -i "\\|[[:space:]]$mount_point[[:space:]]|d" /etc/fstab
printf 'UUID=%s %s %s defaults 0 2\n' "$uuid" "$mount_point" "$fs" >> /etc/fstab
mount "$mount_point"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-storage/xfs-grow-online}" > /var/lib/lfcs-simulator/current-task
