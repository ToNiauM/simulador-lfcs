#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

user="$(task_param username)"
script="$(task_param script_path)"

id -u "$user" &>/dev/null || useradd -m -s /bin/bash "$user"

mkdir -p "$(dirname "$script")"
cat > "$script" <<'EOF'
#!/usr/bin/env bash
df -h > "${HOME:-/tmp}/disk-report.txt"
EOF
chmod 0755 "$script"

# Start from a clean state: no personal crontab for the user.
crontab -r -u "$user" 2>/dev/null || true

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/cron-job-user}" > /var/lib/lfcs-simulator/current-task
