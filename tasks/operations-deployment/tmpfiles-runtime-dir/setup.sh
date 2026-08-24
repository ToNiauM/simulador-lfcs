#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

owner="$(task_param dir_owner)"
group="$(task_param dir_group)"
runtime_dir="$(task_param runtime_dir)"

getent group "$group" > /dev/null || groupadd --system "$group"
id -u "$owner" &> /dev/null || useradd --system --gid "$group" --shell /usr/sbin/nologin --home-dir /nonexistent --no-create-home "$owner"

# Ensure a clean slate: no pre-existing directory or tmpfiles entry.
rm -rf "$runtime_dir"
rm -f "/etc/tmpfiles.d/$(basename "$runtime_dir").conf"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/tmpfiles-runtime-dir}" > /var/lib/lfcs-simulator/current-task
