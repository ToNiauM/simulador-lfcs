#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

new_hostname="$(task_param new_hostname)"
host_a="$(task_param host_a)"
fqdn_a="$(task_param fqdn_a)"
ip_a="$(task_param ip_a)"
host_b="$(task_param host_b)"
fqdn_b="$(task_param fqdn_b)"
ip_b="$(task_param ip_b)"

hostnamectl set-hostname "$new_hostname"

# Replace any previous entries for these names, then append fresh ones.
sed -i -e "/[[:space:]]${host_a}\\(\\.\\|[[:space:]]\\|$\\)/d" -e "/[[:space:]]${host_b}\\(\\.\\|[[:space:]]\\|$\\)/d" /etc/hosts
printf '%s %s %s\n' "$ip_a" "$fqdn_a" "$host_a" >> /etc/hosts
printf '%s %s %s\n' "$ip_b" "$fqdn_b" "$host_b" >> /etc/hosts
