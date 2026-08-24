#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/systemd-timer-scheduled","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

name = p["timer_name"]
timer = name + ".timer"
script = p["script_path"]
spec = p["on_calendar"]

# Normalize the requested calendar spec so equivalent notations are accepted.
normalized = spec
for line in run("systemd-analyze", "calendar", spec).splitlines():
    if "Normalized form" in line:
        normalized = line.split(":", 1)[1].strip()
        break
timers_calendar = run("systemctl", "show", timer, "-p", "TimersCalendar", "--value")
ok1 = normalized in timers_calendar or spec in timers_calendar
c1 = criterion("timer_calendar", ok1, 2, "timer fires on the requested calendar schedule", timers_calendar or "timer has no calendar entry")

active = run("systemctl", "is-active", timer)
c2 = criterion("timer_active", active == "active", 2, "timer is currently active", active or "unknown")

enabled = run("systemctl", "is-enabled", timer)
c3 = criterion("timer_enabled", enabled == "enabled", 2, "timer starts automatically at boot", enabled or "unknown")

triggered = run("systemctl", "show", timer, "-p", "Unit", "--value") or (name + ".service")
exec_start = run("systemctl", "show", triggered, "-p", "ExecStart", "--value")
c4 = criterion("service_runs_script", triggered == name + ".service" and script in exec_start, 2,
               "timer triggers the service that runs the maintenance script", f"Unit={triggered} ExecStart={exec_start or '-'}")

listed = run("systemctl", "list-timers", "--all", "--no-legend", "--no-pager")
c5 = criterion("timer_listed", timer in listed, 2, "timer appears in the scheduled timers list",
               next((line for line in listed.splitlines() if timer in line), "not listed"))

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
