#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

content_dir="$(task_param content_dir)"
http_port="$(task_param http_port)"

site=/etc/nginx/sites-available/lfcs-static.conf
cat > "$site" <<CONF
server {
    listen ${http_port};
    listen [::]:${http_port};
    root ${content_dir};
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
CONF
mkdir -p /etc/nginx/sites-enabled
ln -sfn "$site" /etc/nginx/sites-enabled/lfcs-static.conf
nginx -t
systemctl enable --now nginx
systemctl reload nginx
