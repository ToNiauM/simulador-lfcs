#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

command -v ss >/dev/null 2>&1 || { echo "ss (iproute2) is not installed in this guest image" >&2; exit 69; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is not installed in this guest image" >&2; exit 69; }

report_path="$(task_param report_path)"
rm -f "$report_path"

make_listener() {
  local service="$1" port="$2"
  systemctl disable --now "${service}.service" 2>/dev/null || true
  cat > "/etc/systemd/system/${service}.service" <<UNIT
[Unit]
Description=LFCS test listener ${service} on 127.0.0.1:${port}
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server ${port} --bind 127.0.0.1
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now "${service}.service"
}

make_listener "$(task_param svc_a)" "$(task_param port_a)"
make_listener "$(task_param svc_b)" "$(task_param port_b)"

# Wait until both fixture ports are answering locally.
python3 - "$(task_param port_a)" "$(task_param port_b)" <<'PY'
import socket, sys, time
for port in (int(sys.argv[1]), int(sys.argv[2])):
    for _ in range(50):
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=1):
                break
        except OSError:
            time.sleep(0.2)
    else:
        sys.exit(f"fixture listener on port {port} did not start")
PY

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/listening-services-inventory}" > /var/lib/lfcs-simulator/current-task
