#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
base_dir="$(task_param base_dir)"
default_shell="$(task_param default_shell)"

mkdir -p "$base_dir"
useradd -D -s "$default_shell" >/dev/null
useradd -D -b "$base_dir" >/dev/null
useradd -m "$username"
