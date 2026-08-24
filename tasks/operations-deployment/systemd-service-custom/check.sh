#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/systemd-service-custom","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

unit = p["service_name"] + ".service"
script = p["script_path"]

fragment = run("systemctl", "show", unit, "-p", "FragmentPath", "--value")
loaded = run("systemctl", "show", unit, "-p", "LoadState", "--value")
c1 = criterion("unit_file_present", bool(fragment) and os.path.isfile(fragment) and loaded == "loaded", 2,
               "service unit file exists and loads", fragment or "unit file not found")

exec_start = run("systemctl", "show", unit, "-p", "ExecStart", "--value")
c2 = criterion("exec_start", script in exec_start, 2,
               "unit executes the provided worker script", exec_start or "ExecStart empty")

restart = run("systemctl", "show", unit, "-p", "Restart", "--value")
c3 = criterion("restart_policy", restart == "on-failure", 2,
               "unit restarts only on failure", f"Restart={restart or 'unset'}")

active = run("systemctl", "is-active", unit)
c4 = criterion("service_active", active == "active", 2,
               "service is currently running", active or "unknown")

enabled = run("systemctl", "is-enabled", unit)
wanted_by = run("systemctl", "show", unit, "-p", "WantedBy", "--value")
ok5 = enabled == "enabled" and "multi-user.target" in wanted_by.split()
c5 = criterion("enabled_multi_user", ok5, 2,
               "service is enabled and wanted by multi-user.target", f"is-enabled={enabled or 'unknown'} WantedBy={wanted_by or '-'}")

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
