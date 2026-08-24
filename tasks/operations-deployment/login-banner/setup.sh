#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

command -v sshd > /dev/null || { echo "openssh-server is required in the guest image" >&2; exit 65; }

# Ensure a clean slate: no banner configured, default motd content.
sed -i '/^[[:space:]]*Banner[[:space:]]/d' /etc/ssh/sshd_config
if [[ -d /etc/ssh/sshd_config.d ]]; then
  for f in /etc/ssh/sshd_config.d/*.conf; do
    [[ -e "$f" ]] && sed -i '/^[[:space:]]*Banner[[:space:]]/d' "$f"
  done
fi
printf 'Ubuntu lab guest\n' > /etc/motd
rm -f /etc/issue.net

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/login-banner}" > /var/lib/lfcs-simulator/current-task
