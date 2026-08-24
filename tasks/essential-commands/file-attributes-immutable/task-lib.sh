#!/usr/bin/env bash
set -euo pipefail

task_param() {
  python3 - "$LFCS_PARAMS_FILE" "$1" <<'PY'
import json, sys
with open(sys.argv[1]) as handle:
    payload = json.load(handle)
print(payload["params"][sys.argv[2]])
PY
}

require_guest_root() {
  [[ "${LFCS_GUEST_LAB:-}" == "1" ]] || { echo "refusing outside LFCS guest lab" >&2; exit 64; }
  [[ "$(id -u)" == "0" ]] || { echo "must run as root" >&2; exit 77; }
  [[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo "LFCS_PARAMS_FILE is required" >&2; exit 64; }
}
