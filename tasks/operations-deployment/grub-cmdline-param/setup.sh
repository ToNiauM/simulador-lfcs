#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

[[ -f /etc/default/grub ]] || { echo "/etc/default/grub not found; GRUB is required for this task" >&2; exit 69; }
command -v update-grub >/dev/null || command -v grub-mkconfig >/dev/null || command -v grub2-mkconfig >/dev/null || command -v grubby >/dev/null || { echo "no GRUB regeneration tool found (update-grub/grub-mkconfig/grub2-mkconfig/grubby); refusing (no network installs in lab)" >&2; exit 69; }

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/grub-cmdline-param}" > /var/lib/lfcs-simulator/current-task
