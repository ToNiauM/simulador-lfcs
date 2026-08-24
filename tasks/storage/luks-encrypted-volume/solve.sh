#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
fs="$(task_param filesystem)"
size="$(task_param part_size_mib)"
mapper="$(task_param mapper_name)"
key_file="$(task_param key_file)"
mount_point="$(task_param mount_point)"

parted -s "$disk" mklabel gpt mkpart crypt 1MiB "$((size + 1))MiB"
udevadm settle
part="${disk}1"
dd if=/dev/urandom of="$key_file" bs=64 count=64 status=none
chmod 600 "$key_file"
cryptsetup luksFormat --type luks2 --batch-mode "$part" "$key_file"
cryptsetup open "$part" "$mapper" --key-file "$key_file"
mkfs -t "$fs" -F "/dev/mapper/$mapper"
luks_uuid="$(blkid -s UUID -o value "$part")"
touch /etc/crypttab
sed -i "/^$mapper[[:space:]]/d" /etc/crypttab
printf '%s UUID=%s %s luks\n' "$mapper" "$luks_uuid" "$key_file" >> /etc/crypttab
mkdir -p "$mount_point"
sed -i "\\|[[:space:]]$mount_point[[:space:]]|d" /etc/fstab
printf '/dev/mapper/%s %s %s defaults 0 2\n' "$mapper" "$mount_point" "$fs" >> /etc/fstab
mount "$mount_point"
