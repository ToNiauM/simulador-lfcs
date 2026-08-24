#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

name="$(task_param timer_name)"
script="$(task_param script_path)"
calendar="$(task_param on_calendar)"

cat > "/etc/systemd/system/${name}.service" <<EOF
[Unit]
Description=LFCS maintenance job ${name}

[Service]
Type=oneshot
ExecStart=${script}
EOF

cat > "/etc/systemd/system/${name}.timer" <<EOF
[Unit]
Description=LFCS maintenance schedule ${name}

[Timer]
OnCalendar=${calendar}

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now "${name}.timer"
