#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

mount_point="$(task_param mount_point)"
size="$(task_param size_mib)"
mode="$(task_param mode)"

mkdir -p "$mount_point"
sed -i "\\|[[:space:]]$mount_point[[:space:]]|d" /etc/fstab
printf 'tmpfs %s tmpfs size=%sM,mode=%s 0 0\n' "$mount_point" "$size" "$mode" >> /etc/fstab
mount "$mount_point"
