#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
size="$(task_param part_size_mib)"
fs="$(task_param filesystem)"
label="$(task_param fs_label)"
mount_point="$(task_param mount_point)"

sfdisk --wipe always "$disk" <<SF
label: gpt
,${size}MiB
SF
udevadm settle 2>/dev/null || true
part="${disk}1"
mkfs -t "$fs" -F -L "$label" "$part"
mkdir -p "$mount_point"
sed -i "\\|[[:space:]]$mount_point[[:space:]]|d" /etc/fstab
printf 'LABEL=%s %s %s defaults 0 2\n' "$label" "$mount_point" "$fs" >> /etc/fstab
mount "$mount_point"
