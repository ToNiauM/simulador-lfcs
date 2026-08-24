#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

# Idempotency: strip any pre-existing proxy variables from /etc/environment.
touch /etc/environment
sed -i -E '/^[[:space:]]*(export[[:space:]]+)?(http_proxy|https_proxy|ftp_proxy|no_proxy|HTTP_PROXY|HTTPS_PROXY|FTP_PROXY|NO_PROXY)=/d' /etc/environment

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/system-proxy-env}" > /var/lib/lfcs-simulator/current-task
