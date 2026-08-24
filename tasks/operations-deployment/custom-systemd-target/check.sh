#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/custom-systemd-target","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

target = p["target_name"]
services = [p["service_a"], p["service_b"]]

load_state = run("systemctl", "show", target, "-p", "LoadState", "--value")
c1 = criterion("target_loaded", load_state == "loaded", 2, "custom target exists and loads", load_state or "unit missing")

wants = run("systemctl", "show", target, "-p", "Wants", "--value").split()
missing_wants = [svc for svc in services if svc not in wants]
c2 = criterion("target_wants", load_state == "loaded" and not missing_wants, 3, "target wants both services (Wants)", " ".join(wants) or "no Wants")

after = run("systemctl", "show", target, "-p", "After", "--value").split()
missing_after = [svc for svc in services if svc not in after]
c3 = criterion("target_after", load_state == "loaded" and not missing_after, 2, "target is ordered after both services (After)", " ".join(sorted(set(after) & set(services))) or "no relevant After")

wants_dir = f"/etc/systemd/system/{target}.wants"
links = []
linked = True
for svc in services:
    path = os.path.join(wants_dir, svc)
    if os.path.lexists(path):
        links.append(path)
    else:
        linked = False
c4 = criterion("wants_symlinks", linked, 3, "enablement links present in the target .wants directory", "; ".join(links) or f"{wants_dir} missing expected links")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
