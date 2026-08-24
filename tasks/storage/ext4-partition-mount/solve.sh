#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
size="$(task_param part_size_mib)"
fs="$(task_param filesystem)"
mount_point="$(task_param mount_point)"
option="$(task_param mount_option)"

sfdisk --wipe always "$disk" <<SF
label: gpt
,${size}MiB
SF
udevadm settle 2>/dev/null || true
part="${disk}1"
mkfs -t "$fs" -F "$part"
mkdir -p "$mount_point"
uuid="$(blkid -s UUID -o value "$part")"
sed -i "\\|[[:space:]]$mount_point[[:space:]]|d" /etc/fstab
printf 'UUID=%s %s %s defaults,%s 0 2\n' "$uuid" "$mount_point" "$fs" "$option" >> /etc/fstab
mount "$mount_point"
