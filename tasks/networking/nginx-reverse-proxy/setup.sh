#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

# nginx must be pre-installed in the guest image; never install from the Internet.
command -v nginx >/dev/null 2>&1 || { echo "nginx is not installed in this guest image; bake it into the image (setup never downloads packages)" >&2; exit 69; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is not installed in this guest image" >&2; exit 69; }

service="$(task_param backend_service)"
backend_dir="$(task_param backend_dir)"
backend_port="$(task_param backend_port)"
content_token="$(task_param content_token)"

systemctl disable --now "${service}.service" 2>/dev/null || true
rm -rf "$backend_dir"
mkdir -p "$backend_dir"
cat > "$backend_dir/index.html" <<HTML
<!doctype html>
<html><head><title>LFCS backend</title></head>
<body><p>LFCS backend token: ${content_token}</p></body></html>
HTML

cat > "/etc/systemd/system/${service}.service" <<UNIT
[Unit]
Description=LFCS deterministic backend web server (${service})
After=network.target

[Service]
ExecStart=/usr/bin/python3 -m http.server ${backend_port} --bind 127.0.0.1 --directory ${backend_dir}
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now "${service}.service"

# Wait until the backend is answering locally (no Internet involved).
python3 - "$backend_port" <<'PY'
import socket, sys, time
port = int(sys.argv[1])
for _ in range(50):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=1):
            sys.exit(0)
    except OSError:
        time.sleep(0.2)
sys.exit("backend service did not start listening")
PY

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/nginx-reverse-proxy}" > /var/lib/lfcs-simulator/current-task
