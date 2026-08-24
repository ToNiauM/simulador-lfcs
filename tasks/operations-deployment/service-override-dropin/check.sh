#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/service-override-dropin","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

unit = p["service_name"] + ".service"
override = f"/etc/systemd/system/{unit}.d/override.conf"
policy = p["restart_policy"]
env_pair = f"{p['env_name']}={p['env_value']}"

c1 = criterion("override_file", os.path.isfile(override), 2, "drop-in override.conf exists",
               override if os.path.isfile(override) else "override.conf missing")

dropins = run("systemctl", "show", unit, "-p", "DropInPaths", "--value")
c2 = criterion("dropin_loaded", override in dropins.split(), 2,
               "service manager has loaded the drop-in", dropins or "no drop-in paths loaded")

restart = run("systemctl", "show", unit, "-p", "Restart", "--value")
c3 = criterion("restart_policy", restart == policy, 3,
               "running configuration uses the requested restart policy", f"Restart={restart or 'unset'}")

environment = run("systemctl", "show", unit, "-p", "Environment", "--value")
c4 = criterion("environment_set", env_pair in environment.split(), 3,
               "running configuration includes the requested environment variable", environment or "Environment empty")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
