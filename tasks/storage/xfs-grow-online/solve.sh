#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

vg="$(task_param vg_name)"
lv="$(task_param lv_name)"
target="$(task_param target_size_mib)"
mount_point="$(task_param mount_point)"

lvextend -L "${target}M" "/dev/$vg/$lv"
xfs_growfs "$mount_point"
