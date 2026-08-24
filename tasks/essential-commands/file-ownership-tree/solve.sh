#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

tree_dir="$(task_param tree_dir)"
owner_user="$(task_param owner_user)"
owner_group="$(task_param owner_group)"

chown -R "$owner_user:$owner_group" "$tree_dir"
