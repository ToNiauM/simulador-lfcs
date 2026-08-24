#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

target="$(task_param target_name)"
svc_a="$(task_param service_a)"
svc_b="$(task_param service_b)"

cat > "/etc/systemd/system/$target" <<UNIT
[Unit]
Description=LFCS custom lab target
Wants=$svc_a $svc_b
After=$svc_a $svc_b
UNIT
systemctl daemon-reload
systemctl add-wants "$target" "$svc_a" "$svc_b"
systemctl daemon-reload
