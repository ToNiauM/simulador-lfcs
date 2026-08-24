#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

conf="$(task_param conf_file)"
new_port="$(task_param new_port)"
new_level="$(task_param new_log_level)"

sed -i -e "s/^port=.*/port=${new_port}/" -e "s/^log_level=.*/log_level=${new_level}/" "$conf"
