#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
fs="$(task_param filesystem)"
size="$(task_param part_size_mib)"
mount_point="$(task_param mount_point)"

parted -s "$disk" mklabel gpt mkpart archive 1MiB "$((size + 1))MiB"
udevadm settle
part="${disk}1"
mkfs -t "$fs" -F "$part"
mkdir -p "$mount_point"
uuid="$(blkid -s UUID -o value "$part")"
sed -i "\\|[[:space:]]$mount_point[[:space:]]|d" /etc/fstab
printf 'UUID=%s %s %s ro 0 2\n' "$uuid" "$mount_point" "$fs" >> /etc/fstab
mount "$mount_point"
