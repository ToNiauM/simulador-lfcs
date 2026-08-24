#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

[[ -x /usr/sbin/sshd ]] || { echo "openssh-server is required in the guest image" >&2; exit 65; }
match_user="$(task_param match_user)"

# Fixture account targeted by the Match User block.
if ! id -u "$match_user" &>/dev/null; then
  useradd -m -s /bin/bash "$match_user"
fi

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/ssh-harden-config}" > /var/lib/lfcs-simulator/current-task
