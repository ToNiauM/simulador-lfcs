#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

command -v podman >/dev/null || { echo "podman is required for this task but is not installed; refusing to continue (network installs are forbidden in the lab)" >&2; exit 69; }
generator=/usr/lib/systemd/system-generators/podman-system-generator
[[ -x "$generator" ]] || { echo "podman Quadlet generator missing at $generator; refusing to continue (network installs are forbidden in the lab)" >&2; exit 69; }

container_file="$(task_param container_file)"
mkdir -p /etc/containers/systemd
rm -f "$container_file"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/quadlet-container-unit}" > /var/lib/lfcs-simulator/current-task
