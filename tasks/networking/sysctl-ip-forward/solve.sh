#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

sysctl_file="$(task_param sysctl_file)"

printf 'net.ipv4.ip_forward = 1\n' > "$sysctl_file"
sysctl -p "$sysctl_file" >/dev/null
