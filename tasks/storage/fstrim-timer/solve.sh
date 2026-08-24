#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

day="$(task_param trim_day)"
time="$(task_param trim_time)"

mkdir -p /etc/systemd/system/fstrim.timer.d
printf '[Timer]\nOnCalendar=\nOnCalendar=%s *-*-* %s:00\n' "$day" "$time" > /etc/systemd/system/fstrim.timer.d/override.conf
systemctl daemon-reload
systemctl enable --now fstrim.timer
