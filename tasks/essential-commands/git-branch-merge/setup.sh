#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

repo_dir="$(task_param repo_dir)"
main_branch="$(task_param main_branch)"
base_file="$(task_param base_file)"

rm -rf "$repo_dir"
mkdir -p "$repo_dir"
git -C "$repo_dir" init -q -b "$main_branch"
git -C "$repo_dir" config user.name "LFCS Lab"
git -C "$repo_dir" config user.email "lab@example.com"
task_param base_content > "$repo_dir/$base_file"
git -C "$repo_dir" add -A
git -C "$repo_dir" commit -q -m "Base do projeto"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/git-branch-merge}" > /var/lib/lfcs-simulator/current-task
