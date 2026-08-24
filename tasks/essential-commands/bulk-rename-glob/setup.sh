#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

work_dir="$(task_param work_dir)"
prefix="$(task_param prefix)"
old_ext="$(task_param old_ext)"
new_ext="$(task_param new_ext)"
count="$(task_param count)"
lot_id="$(task_param lot_id)"
keep_file="$(task_param keep_file)"

rm -rf "$work_dir"
mkdir -p "$work_dir"
for ((i = 1; i <= count; i++)); do
  name="$(printf '%s-%02d' "$prefix" "$i")"
  printf 'registro %s lote %s\n' "$name" "$lot_id" > "$work_dir/$name.$old_ext"
done
printf 'resumo do lote %s\n' "$lot_id" > "$work_dir/$keep_file"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/bulk-rename-glob}" > /var/lib/lfcs-simulator/current-task
