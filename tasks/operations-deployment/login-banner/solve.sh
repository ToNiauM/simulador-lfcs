#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

banner_file="$(task_param banner_file)"
banner_text="$(task_param banner_text)"
motd_text="$(task_param motd_text)"

printf '%s\n' "$banner_text" > "$banner_file"
printf '%s\n' "$motd_text" > /etc/motd

mkdir -p /etc/ssh/sshd_config.d
printf 'Banner %s\n' "$banner_file" > /etc/ssh/sshd_config.d/60-lfcs-banner.conf
sshd -t
systemctl reload ssh 2> /dev/null || systemctl reload sshd 2> /dev/null || true
