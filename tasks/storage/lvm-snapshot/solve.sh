#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

vg="$(task_param vg_name)"
origin="$(task_param origin_lv)"
snap="$(task_param snap_name)"
size="$(task_param snap_size_mib)"

lvcreate -y -s -L "${size}M" -n "$snap" "/dev/$vg/$origin"
