#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

service="$(task_param service_name)"

mkdir -p /usr/local/lib/lfcs
cat > "/usr/local/lib/lfcs/${service}.sh" <<'EOF'
#!/usr/bin/env bash
exec sleep infinity
EOF
chmod 755 "/usr/local/lib/lfcs/${service}.sh"

rm -rf "/etc/systemd/system/${service}.service.d"
cat > "/etc/systemd/system/${service}.service" <<EOF
[Unit]
Description=LFCS lab worker ${service}

[Service]
ExecStart=/usr/local/lib/lfcs/${service}.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "${service}.service"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/service-resource-limits}" > /var/lib/lfcs-simulator/current-task
