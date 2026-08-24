#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

user="$(task_param restricted_user)"

# Create the target account (idempotent) without touching any SSH config.
if ! getent passwd "$user" >/dev/null; then
  useradd -m -s /bin/bash "$user"
fi

# Idempotency: remove any previous drop-in of ours mentioning this user.
if [[ -d /etc/ssh/sshd_config.d ]]; then
  while IFS= read -r conf; do
    rm -f "$conf"
  done < <(grep -l -- "Match User $user" /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true)
fi

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/sshd-match-restrictions}" > /var/lib/lfcs-simulator/current-task
