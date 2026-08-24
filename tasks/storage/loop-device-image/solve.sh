#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

image="$(task_param image_path)"
size="$(task_param size_mib)"
fs="$(task_param filesystem)"
mount_point="$(task_param mount_point)"

dd if=/dev/zero of="$image" bs=1M count="$size" status=none
mkfs -t "$fs" -F "$image"
mkdir -p "$mount_point"
sed -i "\\|[[:space:]]$mount_point[[:space:]]|d" /etc/fstab
printf '%s %s %s loop 0 0\n' "$image" "$mount_point" "$fs" >> /etc/fstab
mount "$mount_point"
