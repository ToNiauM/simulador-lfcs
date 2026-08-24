#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

conf="$(task_param conf_file)"
swappiness="$(task_param swappiness)"
pid_max="$(task_param pid_max)"

mkdir -p "$(dirname "$conf")"
cat > "$conf" <<EOF
vm.swappiness = $swappiness
kernel.pid_max = $pid_max
EOF

sysctl -p "$conf" >/dev/null
