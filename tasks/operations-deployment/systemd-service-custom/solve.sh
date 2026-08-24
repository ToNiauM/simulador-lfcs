#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

name="$(task_param service_name)"
script="$(task_param script_path)"

cat > "/etc/systemd/system/${name}.service" <<EOF
[Unit]
Description=LFCS batch worker ${name}

[Service]
ExecStart=${script}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "${name}.service"
