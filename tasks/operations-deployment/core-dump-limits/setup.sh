#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

limits_file="$(task_param limits_file)"
sysctl_file="$(task_param sysctl_file)"
sysctl_key="$(task_param sysctl_key)"

# Clean slate: the candidate must create both files.
rm -f "$limits_file" "$sysctl_file"

# Ensure the active value differs from the required one so the check fails pre-solve.
case "$sysctl_key" in
  fs.suid_dumpable) sysctl -w fs.suid_dumpable=2 >/dev/null ;;
  kernel.core_pattern) sysctl -w kernel.core_pattern=core >/dev/null ;;
esac

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/core-dump-limits}" > /var/lib/lfcs-simulator/current-task
