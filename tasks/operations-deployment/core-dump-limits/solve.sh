#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

limits_file="$(task_param limits_file)"
sysctl_file="$(task_param sysctl_file)"
sysctl_key="$(task_param sysctl_key)"
sysctl_value="$(task_param sysctl_value)"

printf '* hard core 0\n' > "$limits_file"
printf '%s = %s\n' "$sysctl_key" "$sysctl_value" > "$sysctl_file"

# On Ubuntu, apport rewrites kernel.core_pattern at boot; disable it so the
# persisted value survives a reboot.
if [[ "$sysctl_key" == "kernel.core_pattern" ]] && systemctl list-unit-files apport.service >/dev/null 2>&1; then
  systemctl disable --now apport.service >/dev/null 2>&1 || true
fi

sysctl -w "$sysctl_key=$sysctl_value" >/dev/null
