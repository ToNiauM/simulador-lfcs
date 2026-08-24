#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

src="$(task_param source_dir)"
target="$(task_param bind_target)"

mkdir -p "$target"
sed -i "\\|[[:space:]]$target[[:space:]]|d" /etc/fstab
printf '%s %s none bind 0 0\n' "$src" "$target" >> /etc/fstab
mount "$target"
