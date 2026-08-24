#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

[[ -x /usr/sbin/sshd ]] || { echo "openssh-server is required in the guest image" >&2; exit 65; }
port="$(task_param extra_port)"

# Clean starting point: the extra port must not be configured yet.
if /usr/sbin/sshd -T 2>/dev/null | grep -qx "port ${port}"; then
  echo "sshd already listens on ${port}; expected a clean guest" >&2
  exit 65
fi

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/ssh-additional-port}" > /var/lib/lfcs-simulator/current-task
