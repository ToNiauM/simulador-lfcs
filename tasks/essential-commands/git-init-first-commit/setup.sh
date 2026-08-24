#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

repo_dir="$(task_param repo_dir)"
file1_name="$(task_param file1_name)"
file2_name="$(task_param file2_name)"

rm -rf "$repo_dir/.git"
mkdir -p "$repo_dir"
task_param file1_content > "$repo_dir/$file1_name"
task_param file2_content > "$repo_dir/$file2_name"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/git-init-first-commit}" > /var/lib/lfcs-simulator/current-task
