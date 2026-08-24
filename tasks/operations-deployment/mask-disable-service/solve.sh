#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

svc_mask="$(task_param service_mask)"
svc_disable="$(task_param service_disable)"

systemctl disable --now "$svc_mask"
systemctl mask "$svc_mask"
systemctl disable --now "$svc_disable"
