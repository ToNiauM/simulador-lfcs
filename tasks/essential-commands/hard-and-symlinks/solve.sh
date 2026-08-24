#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

hard_target="$(task_param hard_target)"
hard_link="$(task_param hard_link)"
sym_target="$(task_param sym_target)"
sym_link="$(task_param sym_link)"

ln -f "$hard_target" "$hard_link"
ln -sfn "$sym_target" "$sym_link"
