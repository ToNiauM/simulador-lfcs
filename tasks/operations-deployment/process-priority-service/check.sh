#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/process-priority-service","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

unit = p["service_name"] + ".service"
expected_nice = str(p["nice_value"])
expected_class = p["io_class"]
# systemd may report the I/O class as a name or as its numeric value.
class_aliases = {"none": "0", "realtime": "1", "best-effort": "2", "idle": "3"}
accepted_classes = {expected_class, class_aliases.get(expected_class, "")}

state = run("systemctl", "is-active", unit)
main_pid = run("systemctl", "show", unit, "-p", "MainPID", "--value")
active_ok = state == "active" and main_pid.isdigit() and int(main_pid) > 0
c1 = criterion("service_active", active_ok, 2, "service is running with a main process", f"is-active={state or 'unknown'} MainPID={main_pid or '?'}")

enabled = run("systemctl", "is-enabled", unit)
c2 = criterion("service_enabled", enabled == "enabled", 2, "service starts automatically at boot", f"is-enabled: {enabled or 'unknown'}")

nice_prop = run("systemctl", "show", unit, "-p", "Nice", "--value")
c3 = criterion("nice_configured", nice_prop == expected_nice, 2, "unit is configured with the requested niceness", f"Nice={nice_prop or 'unset'} (expected {expected_nice})")

runtime_nice = ""
if active_ok:
    try:
        stat = open(f"/proc/{main_pid}/stat").read()
        # Field 19 (1-based) is the nice value; split after the comm field.
        fields = stat.rsplit(")", 1)[1].split()
        runtime_nice = fields[16]
    except (OSError, IndexError):
        runtime_nice = ""
c4 = criterion("nice_runtime", runtime_nice == expected_nice, 2, "running process has the requested niceness", f"/proc/{main_pid or '?'}/stat nice={runtime_nice or 'unavailable'}")

io_class = run("systemctl", "show", unit, "-p", "IOSchedulingClass", "--value")
c5 = criterion("io_class", io_class in accepted_classes and bool(io_class), 2, "unit is configured with the requested I/O scheduling class", f"IOSchedulingClass={io_class or 'unset'} (expected {expected_class})")

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
