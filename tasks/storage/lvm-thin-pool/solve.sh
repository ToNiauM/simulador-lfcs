#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

vg="$(task_param vg_name)"
pool="$(task_param pool_name)"
thin="$(task_param thin_lv_name)"
pool_size="$(task_param pool_size_mib)"
virtual_size="$(task_param thin_virtual_size_mib)"

lvcreate -y -L "${pool_size}M" -T "$vg/$pool"
lvcreate -y -V "${virtual_size}M" -T "$vg/$pool" -n "$thin"
