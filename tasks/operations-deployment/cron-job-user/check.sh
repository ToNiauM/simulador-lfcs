#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/cron-job-user","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

user = p["username"]
script = p["script_path"]
minute = str(p["minute"])
hour = str(p["hour"])

proc = subprocess.run(["crontab", "-l", "-u", user], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
listing = proc.stdout if proc.returncode == 0 else ""
entries = []
for line in listing.splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or "=" in stripped.split()[0]:
        continue
    fields = stripped.split()
    if len(fields) >= 6:
        entries.append(fields)
c1 = criterion("crontab_present", proc.returncode == 0 and bool(entries), 3,
               "user has a personal crontab with at least one job", listing.strip() or "no crontab for user")

schedule_ok = [e for e in entries if e[0] == minute and e[1] == hour and e[2] == "*" and e[3] == "*" and e[4] == "*"]
c2 = criterion("schedule_matches", bool(schedule_ok), 4,
               "a job is scheduled daily at the requested hour and minute",
               " ".join(schedule_ok[0][:5]) if schedule_ok else f"no entry with schedule {minute} {hour} * * *")

command_ok = [e for e in schedule_ok if script in " ".join(e[5:])]
c3 = criterion("command_matches", bool(command_ok), 3,
               "the scheduled job runs the report script",
               " ".join(command_ok[0]) if command_ok else "no matching entry runs " + script)

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
