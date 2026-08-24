#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

name="$(task_param timer_name)"
script="$(task_param script_path)"

mkdir -p "$(dirname "$script")"
cat > "$script" <<'EOF'
#!/usr/bin/env bash
logger -t lfcs-maintenance "maintenance job executed"
EOF
chmod 0755 "$script"

# Remove any leftover units so the guest starts from a clean state.
systemctl disable --now "${name}.timer" 2>/dev/null || true
systemctl stop "${name}.service" 2>/dev/null || true
rm -f "/etc/systemd/system/${name}.service" "/etc/systemd/system/${name}.timer"
rm -rf "/etc/systemd/system/${name}.service.d" "/etc/systemd/system/${name}.timer.d"
systemctl daemon-reload

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/systemd-timer-scheduled}" > /var/lib/lfcs-simulator/current-task
