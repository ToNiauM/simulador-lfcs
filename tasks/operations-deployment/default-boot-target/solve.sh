#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

expected="$(task_param expected_target)"

systemctl set-default "$expected"
