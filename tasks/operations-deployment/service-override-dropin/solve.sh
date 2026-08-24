#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

name="$(task_param service_name)"
policy="$(task_param restart_policy)"
env_name="$(task_param env_name)"
env_value="$(task_param env_value)"

mkdir -p "/etc/systemd/system/${name}.service.d"
cat > "/etc/systemd/system/${name}.service.d/override.conf" <<EOF
[Service]
Restart=${policy}
Environment=${env_name}=${env_value}
EOF

systemctl daemon-reload
systemctl restart "${name}.service"
