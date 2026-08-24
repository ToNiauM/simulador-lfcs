#!/usr/bin/env bash
set -euo pipefail

phase="${1:-}"
pack="$(cd "$(dirname "$0")/.." && pwd)"
state=/var/lib/lfcs-simulator/static-ip-secondary-nic-e2e.json
[[ "${LFCS_GUEST_LAB:-}" == "1" && "$(id -u)" == 0 ]] || { echo "run only as root in disposable guest" >&2; exit 64; }

case "$phase" in
  prepare)
    mkdir -p "$(dirname "$state")"
    "$pack/../../../bin/render-task" "$pack" "e2e-static-ip-secondary-nic" "$state"
    export LFCS_TASK_ID=networking/static-ip-secondary-nic LFCS_SEED=e2e-static-ip-secondary-nic LFCS_PARAMS_FILE="$state"
    "$pack/setup.sh"
    result="$($pack/check.sh)"
    python3 - "$result" <<'PY'
import json, sys
assert json.loads(sys.argv[1])["result"] == "fail", "checker must fail after clean setup"
PY
    "$pack/solve.sh"
    echo "prepare passed; force a VM reboot, then run: $0 verify"
    ;;
  verify)
    [[ -r "$state" ]] || { echo "missing state; run prepare first" >&2; exit 65; }
    export LFCS_TASK_ID=networking/static-ip-secondary-nic LFCS_SEED=e2e-static-ip-secondary-nic LFCS_PARAMS_FILE="$state"
    result="$($pack/check.sh)"
    python3 - "$result" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
assert r["result"] == "pass", r
assert r["score"] == r["max_score"] == 10, r
PY
    echo "e2e passed after reboot"
    ;;
  *) echo "usage: $0 prepare|verify" >&2; exit 64 ;;
esac
