#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

container_file="$(task_param container_file)"
image="$(task_param image)"
host_port="$(task_param host_port)"
container_port="$(task_param container_port)"
env_name="$(task_param env_name)"
env_value="$(task_param env_value)"

mkdir -p "$(dirname "$container_file")"
cat > "$container_file" <<UNIT
[Unit]
Description=LFCS lab Quadlet container

[Container]
Image=$image
PublishPort=$host_port:$container_port
Environment=$env_name=$env_value

[Install]
WantedBy=default.target
UNIT
# Refresh generated units; the container is intentionally never started.
systemctl daemon-reload
