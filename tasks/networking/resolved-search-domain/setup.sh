#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

iface="$(task_param interface)"
domain1="$(task_param search_domain_1)"

# Never touch the interface that carries the default route.
default_dev="$(ip -j route show default | python3 -c 'import json,sys; routes=json.load(sys.stdin); print(routes[0].get("dev","") if routes else "")')"
[[ "$default_dev" != "$iface" ]] || { echo "refusing to touch primary interface $iface" >&2; exit 65; }

# Idempotency: remove any previous netplan file of ours carrying the seeded domain.
while IFS= read -r conf; do
  rm -f "$conf"
done < <(grep -l -- "$domain1" /etc/netplan/*.yaml /etc/netplan/*.yml 2>/dev/null || true)

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/resolved-search-domain}" > /var/lib/lfcs-simulator/current-task
