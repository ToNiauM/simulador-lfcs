#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

repo_dir="$(task_param repo_dir)"
author_name="$(task_param author_name)"
author_email="$(task_param author_email)"
commit_message="$(task_param commit_message)"

git -C "$repo_dir" init -q
git -C "$repo_dir" config user.name "$author_name"
git -C "$repo_dir" config user.email "$author_email"
git -C "$repo_dir" add -A
git -C "$repo_dir" commit -q -m "$commit_message"
