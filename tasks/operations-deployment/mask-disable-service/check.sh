#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/mask-disable-service","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

svc_mask = p["service_mask"]
svc_disable = p["service_disable"]

mask_load = run("systemctl", "show", svc_mask, "-p", "LoadState", "--value")
mask_enabled = run("systemctl", "is-enabled", svc_mask)
c1 = criterion("service_masked", mask_load == "masked" and mask_enabled == "masked", 3, "first service is masked", f"LoadState={mask_load or '?'} is-enabled={mask_enabled or '?'}")

mask_active = run("systemctl", "show", svc_mask, "-p", "ActiveState", "--value")
c2 = criterion("masked_stopped", mask_active != "active", 2, "masked service is not running", f"ActiveState={mask_active or '?'}")

dis_enabled = run("systemctl", "is-enabled", svc_disable)
dis_load = run("systemctl", "show", svc_disable, "-p", "LoadState", "--value")
c3 = criterion("service_disabled", dis_enabled == "disabled" and dis_load == "loaded", 3, "second service is disabled but not masked", f"is-enabled={dis_enabled or '?'} LoadState={dis_load or '?'}")

dis_active = run("systemctl", "show", svc_disable, "-p", "ActiveState", "--value")
c4 = criterion("disabled_stopped", dis_active != "active", 2, "disabled service is not running", f"ActiveState={dis_active or '?'}")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
