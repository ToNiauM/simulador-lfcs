#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/fstrim-timer","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

day = p["trim_day"]
time = p["trim_time"]
normalized = f"{day} *-*-* {time}:00"

enabled = run("systemctl", "is-enabled", "fstrim.timer")
c1 = criterion("timer_enabled", enabled == "enabled", 2, "fstrim.timer is enabled to start at boot", enabled or "unknown")

active = run("systemctl", "is-active", "fstrim.timer")
c2 = criterion("timer_active", active == "active", 2, "fstrim.timer is currently active", active or "unknown")

calendar = run("systemctl", "show", "fstrim.timer", "-p", "TimersCalendar", "--value")
c3 = criterion("schedule", normalized in calendar, 3, "timer schedule matches the requested weekly time", calendar or "no calendar configured")

dropins = run("systemctl", "show", "fstrim.timer", "-p", "DropInPaths", "--value")
c4 = criterion("dropin_used", "fstrim.timer.d" in dropins, 3, "schedule is configured through a drop-in file", dropins or "no drop-in configured")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
