#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

name="$(task_param service_name)"
script="$(task_param script_path)"

mkdir -p "$(dirname "$script")"
cat > "$script" <<'EOF'
#!/usr/bin/env bash
while true; do
  sleep 30
done
EOF
chmod 0755 "$script"

rm -rf "/etc/systemd/system/${name}.service.d"
cat > "/etc/systemd/system/${name}.service" <<EOF
[Unit]
Description=LFCS sync agent ${name}

[Service]
ExecStart=${script}
Restart=no

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "${name}.service"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/service-override-dropin}" > /var/lib/lfcs-simulator/current-task
