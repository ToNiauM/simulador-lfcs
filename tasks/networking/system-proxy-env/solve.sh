#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

host="$(task_param proxy_host)"
port="$(task_param proxy_port)"
no_proxy="$(task_param no_proxy)"
url="http://$host:$port"

sed -i -E '/^[[:space:]]*(export[[:space:]]+)?(http_proxy|https_proxy|no_proxy|HTTP_PROXY|HTTPS_PROXY|NO_PROXY)=/d' /etc/environment
cat >> /etc/environment <<EOF
http_proxy="$url"
https_proxy="$url"
no_proxy="$no_proxy"
EOF
