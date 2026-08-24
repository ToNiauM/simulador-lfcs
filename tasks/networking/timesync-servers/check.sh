#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/timesync-servers","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

ntp1 = p["ntp_server_1"]
ntp2 = p["ntp_server_2"]
fallback = p["fallback_server"]

# Parse timesyncd drop-in directory with systemd drop-in semantics (later files win).
ntp_vals, fb_vals = [], []
ntp_src, fb_src = "", ""
for path in sorted(glob.glob("/etc/systemd/timesyncd.conf.d/*.conf")):
    section = ""
    try:
        lines = open(path).read().splitlines()
    except OSError:
        continue
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith(("#", ";")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            continue
        if section != "Time" or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key, value = key.strip(), value.strip()
        if key == "NTP":
            ntp_vals, ntp_src = value.split(), path
        elif key == "FallbackNTP":
            fb_vals, fb_src = value.split(), path

c1 = criterion("dropin_ntp_servers", ntp1 in ntp_vals and ntp2 in ntp_vals, 3,
               "drop-in in /etc/systemd/timesyncd.conf.d sets the required NTP servers",
               f"{ntp_src or 'no drop-in'}: NTP={' '.join(ntp_vals) or '-'}")
c2 = criterion("dropin_fallback", fallback in fb_vals, 2,
               "drop-in sets the required FallbackNTP server",
               f"{fb_src or 'no drop-in'}: FallbackNTP={' '.join(fb_vals) or '-'}")

enabled = run("systemctl", "is-enabled", "systemd-timesyncd.service")
c3 = criterion("service_enabled", enabled == "enabled", 2,
               "systemd-timesyncd service is enabled", enabled or "unknown")
active = run("systemctl", "is-active", "systemd-timesyncd.service")
c4 = criterion("service_active", active == "active", 1,
               "systemd-timesyncd service is active", active or "unknown")

props = {}
for line in run("timedatectl", "show-timesync").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        props[key] = value
system_ntp = props.get("SystemNTPServers", "").split()
fallback_ntp = props.get("FallbackNTPServers", "").split()
runtime_ok = ntp1 in system_ntp and ntp2 in system_ntp and fallback in fallback_ntp
c5 = criterion("runtime_servers", runtime_ok, 2,
               "timedatectl show-timesync reports the configured servers",
               f"SystemNTPServers={' '.join(system_ntp) or '-'} FallbackNTPServers={' '.join(fallback_ntp) or '-'}")

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
