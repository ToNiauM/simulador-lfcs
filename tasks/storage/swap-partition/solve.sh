#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
size="$(task_param swap_size_mib)"
priority="$(task_param swap_priority)"

sfdisk --wipe always "$disk" <<SF
label: gpt
,${size}MiB,S
SF
udevadm settle 2>/dev/null || true
part="${disk}1"
mkswap "$part"
uuid="$(blkid -s UUID -o value "$part")"
sed -i "\\|^UUID=$uuid[[:space:]]|d" /etc/fstab
printf 'UUID=%s none swap pri=%s 0 0\n' "$uuid" "$priority" >> /etc/fstab
swapon -a
