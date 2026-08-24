#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

swap_file="$(task_param swap_file)"
size_mib="$(task_param swap_size_mib)"
swappiness="$(task_param swappiness)"

dd if=/dev/zero of="$swap_file" bs=1M count="$size_mib" status=none
chmod 600 "$swap_file"
mkswap "$swap_file"
swapon "$swap_file"
sed -i "\\|^${swap_file}[[:space:]]|d" /etc/fstab
printf '%s none swap sw 0 0\n' "$swap_file" >> /etc/fstab

printf 'vm.swappiness = %s\n' "$swappiness" > /etc/sysctl.d/90-lfcs-swappiness.conf
sysctl -w "vm.swappiness=$swappiness" > /dev/null
