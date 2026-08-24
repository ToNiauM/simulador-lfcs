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

# Remove any leftover unit so the guest starts from a clean state.
systemctl disable --now "${name}.service" 2>/dev/null || true
rm -f "/etc/systemd/system/${name}.service"
rm -rf "/etc/systemd/system/${name}.service.d"
systemctl daemon-reload

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/systemd-service-custom}" > /var/lib/lfcs-simulator/current-task
