#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

service="$(task_param service_name)"
worker_script="$(task_param worker_script)"

mkdir -p "$(dirname "$worker_script")"
cat > "$worker_script" <<'EOF'
#!/usr/bin/env bash
exec sleep infinity
EOF
chmod 755 "$worker_script"

# Ensure a clean slate: the unit must be created by the candidate.
systemctl disable --now "${service}.service" 2> /dev/null || true
rm -f "/etc/systemd/system/${service}.service"
rm -rf "/etc/systemd/system/${service}.service.d"
systemctl daemon-reload

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/process-priority-service}" > /var/lib/lfcs-simulator/current-task
