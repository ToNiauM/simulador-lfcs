#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
limits_file="$(task_param limits_file)"
soft_nofile="$(task_param soft_nofile)"
hard_nofile="$(task_param hard_nofile)"

mkdir -p "$(dirname "$limits_file")"
{
  printf '%s soft nofile %s\n' "$username" "$soft_nofile"
  printf '%s hard nofile %s\n' "$username" "$hard_nofile"
} > "$limits_file"
