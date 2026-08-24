#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
fs="$(task_param filesystem)"
size="$(task_param part_size_mib)"
mount_point="$(task_param mount_point)"

parted -s "$disk" mklabel gpt \
  mkpart raid1 1MiB "$((size + 1))MiB" \
  mkpart raid2 "$((size + 1))MiB" "$((2 * size + 1))MiB"
udevadm settle
mdadm --create /dev/md0 --level=1 --raid-devices=2 --metadata=1.2 --run "${disk}1" "${disk}2"
mkfs -t "$fs" -F /dev/md0
. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) mdadm_conf=/etc/mdadm/mdadm.conf; mkdir -p /etc/mdadm ;;
  *) mdadm_conf=/etc/mdadm.conf ;;
esac
touch "$mdadm_conf"
sed -i '/^ARRAY[[:space:]]/d' "$mdadm_conf"
mdadm --detail --scan >> "$mdadm_conf"
mkdir -p "$mount_point"
uuid="$(blkid -s UUID -o value /dev/md0)"
sed -i "\\|[[:space:]]$mount_point[[:space:]]|d" /etc/fstab
printf 'UUID=%s %s %s defaults 0 2\n' "$uuid" "$mount_point" "$fs" >> /etc/fstab
mount "$mount_point"
