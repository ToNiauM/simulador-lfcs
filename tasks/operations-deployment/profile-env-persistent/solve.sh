#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

var_name="$(task_param var_name)"
var_value="$(task_param var_value)"
script_path="$(task_param script_path)"

printf 'export %s="%s"\n' "$var_name" "$var_value" > "$script_path"
chmod 755 "$script_path"
