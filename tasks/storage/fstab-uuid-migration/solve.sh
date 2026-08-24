#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
fs="$(task_param filesystem)"
mount_point="$(task_param mount_point)"

part="${disk}1"
uuid="$(blkid -s UUID -o value "$part")"
sed -i "\\|[[:space:]]$mount_point[[:space:]]|d" /etc/fstab
printf 'UUID=%s %s %s defaults 0 2\n' "$uuid" "$mount_point" "$fs" >> /etc/fstab
mountpoint -q "$mount_point" || mount "$mount_point"
