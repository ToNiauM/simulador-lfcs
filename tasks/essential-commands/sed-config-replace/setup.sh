#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

conf="$(task_param conf_file)"

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
content = (
    "# appd main configuration\n"
    "# generated for the LFCS lab\n"
    f"listen_addr={p['listen_addr']}\n"
    f"port={p['old_port']}\n"
    f"max_clients={p['max_clients']}\n"
    f"log_level={p['old_log_level']}\n"
    f"workers={p['workers']}\n"
    f"data_dir={p['data_dir']}\n"
    "# end of file\n"
)
with open(p["conf_file"], "w") as handle:
    handle.write(content)
PY
chmod 0644 "$conf"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/sed-config-replace}" > /var/lib/lfcs-simulator/current-task
