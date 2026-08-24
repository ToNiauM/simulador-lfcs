#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
vg="$(task_param vg_name)"

pvcreate -ff -y "${disk}2"
vgextend "$vg" "${disk}2"
