#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

# nginx must be pre-installed in the guest image; never install from the Internet.
command -v nginx >/dev/null 2>&1 || { echo "nginx is not installed in this guest image; bake it into the image (setup never downloads packages)" >&2; exit 69; }

content_dir="$(task_param content_dir)"
content_token="$(task_param content_token)"

rm -rf "$content_dir"
mkdir -p "$content_dir"
cat > "$content_dir/index.html" <<HTML
<!doctype html>
<html><head><title>LFCS static site</title></head>
<body><p>LFCS verification token: ${content_token}</p></body></html>
HTML
chmod 0755 "$content_dir"
chmod 0644 "$content_dir/index.html"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/nginx-static-site}" > /var/lib/lfcs-simulator/current-task
