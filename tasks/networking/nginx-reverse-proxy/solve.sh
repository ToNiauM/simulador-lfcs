#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

backend_port="$(task_param backend_port)"
public_port="$(task_param public_port)"

site=/etc/nginx/sites-available/lfcs-proxy.conf
cat > "$site" <<CONF
server {
    listen ${public_port};
    listen [::]:${public_port};
    location / {
        proxy_pass http://127.0.0.1:${backend_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
CONF
mkdir -p /etc/nginx/sites-enabled
ln -sfn "$site" /etc/nginx/sites-enabled/lfcs-proxy.conf
nginx -t
systemctl enable --now nginx
systemctl reload nginx
