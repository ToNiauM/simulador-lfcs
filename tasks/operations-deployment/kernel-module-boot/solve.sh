#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

module="$(task_param module)"
numdummies="$(task_param numdummies)"
load_file="$(task_param load_file)"
options_file="$(task_param options_file)"

mkdir -p "$(dirname "$options_file")" "$(dirname "$load_file")"
printf 'options %s numdummies=%s\n' "$module" "$numdummies" > "$options_file"
printf '%s\n' "$module" > "$load_file"

modprobe -r "$module" 2>/dev/null || true
modprobe "$module"
