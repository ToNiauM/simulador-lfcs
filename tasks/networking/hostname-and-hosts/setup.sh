#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

new_hostname="$(task_param new_hostname)"
host_a="$(task_param host_a)"
host_b="$(task_param host_b)"

# Guarantee a clean starting point: the target hostname and the fictitious
# hosts entries must not pre-exist (idempotent re-run on the same guest).
if [[ "$(cat /proc/sys/kernel/hostname)" == "$new_hostname" ]]; then
  hostnamectl set-hostname lfcs-guest
fi
touch /etc/hosts
sed -i -e "/[[:space:]]${host_a}\\(\\.\\|[[:space:]]\\|$\\)/d" -e "/[[:space:]]${host_b}\\(\\.\\|[[:space:]]\\|$\\)/d" /etc/hosts

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/hostname-and-hosts}" > /var/lib/lfcs-simulator/current-task
