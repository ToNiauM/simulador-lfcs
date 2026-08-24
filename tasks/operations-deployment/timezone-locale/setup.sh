#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

# Deterministic starting point that always differs from every task timezone.
timedatectl set-timezone Etc/UTC
command -v locale-gen >/dev/null || { echo "locale-gen not found; the locales package is required (network installs are forbidden in lab)" >&2; exit 69; }

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/timezone-locale}" > /var/lib/lfcs-simulator/current-task
