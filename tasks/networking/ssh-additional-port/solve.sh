#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

port="$(task_param extra_port)"

# Drop-in keeps /etc/ssh/sshd_config untouched. Declaring any Port disables
# the implicit default, so port 22 must be listed explicitly as well.
mkdir -p /etc/ssh/sshd_config.d
printf 'Port 22\nPort %s\n' "$port" > /etc/ssh/sshd_config.d/60-lfcs-extra-port.conf
/usr/sbin/sshd -t

# Ubuntu 24.04 may use socket activation; mirror the ports on the socket so
# the daemon actually listens on both. Existing sessions are not affected.
if systemctl is-enabled ssh.socket >/dev/null 2>&1; then
  mkdir -p /etc/systemd/system/ssh.socket.d
  printf '[Socket]\nListenStream=\nListenStream=22\nListenStream=%s\n' "$port" > /etc/systemd/system/ssh.socket.d/60-lfcs-extra-port.conf
  systemctl daemon-reload
  systemctl restart ssh.socket
fi
systemctl restart ssh.service 2>/dev/null || systemctl restart sshd.service 2>/dev/null || true
