#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

repo_dir="$(task_param repo_dir)"
main_branch="$(task_param main_branch)"
feature_branch="$(task_param feature_branch)"
feature_file="$(task_param feature_file)"
commit_message="$(task_param feature_commit_message)"

git -C "$repo_dir" checkout -q -b "$feature_branch" "$main_branch"
task_param feature_content > "$repo_dir/$feature_file"
git -C "$repo_dir" add "$feature_file"
git -C "$repo_dir" commit -q -m "$commit_message"
git -C "$repo_dir" checkout -q "$main_branch"
git -C "$repo_dir" merge -q --no-edit "$feature_branch"
