#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
vg="$(task_param vg_name)"
lv="$(task_param lv_name)"
size="$(task_param lv_size_mib)"
fs="$(task_param filesystem)"
mount_point="$(task_param mount_point)"

pvcreate -ff -y "$disk"
vgcreate "$vg" "$disk"
lvcreate -y -L "${size}M" -n "$lv" "$vg"
mkfs -t "$fs" "/dev/$vg/$lv"
mkdir -p "$mount_point"
uuid="$(blkid -s UUID -o value "/dev/$vg/$lv")"
sed -i "\\|[[:space:]]$mount_point[[:space:]]|d" /etc/fstab
printf 'UUID=%s %s %s defaults 0 2\n' "$uuid" "$mount_point" "$fs" >> /etc/fstab
mount "$mount_point"
