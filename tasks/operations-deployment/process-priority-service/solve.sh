#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

service="$(task_param service_name)"
worker_script="$(task_param worker_script)"
nice_value="$(task_param nice_value)"
io_class="$(task_param io_class)"

cat > "/etc/systemd/system/${service}.service" <<EOF
[Unit]
Description=LFCS low-priority batch job ${service}

[Service]
ExecStart=${worker_script}
Nice=${nice_value}
IOSchedulingClass=${io_class}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "${service}.service"
