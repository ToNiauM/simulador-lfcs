#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

service="$(task_param service_name)"
memory_mib="$(task_param memory_max_mib)"
cpu_pct="$(task_param cpu_quota_pct)"
tasks_max="$(task_param tasks_max)"

mkdir -p "/etc/systemd/system/${service}.service.d"
cat > "/etc/systemd/system/${service}.service.d/limits.conf" <<EOF
[Service]
MemoryMax=${memory_mib}M
CPUQuota=${cpu_pct}%
TasksMax=${tasks_max}
EOF

systemctl daemon-reload
systemctl restart "${service}.service"
