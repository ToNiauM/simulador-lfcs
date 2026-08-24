#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

username="$(task_param username)"
skel_file="$(task_param skel_file)"
skel_content="$(task_param skel_content)"

printf '%s\n' "$skel_content" > "/etc/skel/$skel_file"
useradd -m "$username"
