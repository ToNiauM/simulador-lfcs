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

# --- systemd-timesyncd: main config plus drop-ins (drop-ins win, later files win).
ntp_vals, fb_vals = [], []
ntp_src, fb_src = "", ""
for path in ["/etc/systemd/timesyncd.conf"] + sorted(glob.glob("/etc/systemd/timesyncd.conf.d/*.conf")):
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
tsync_primary = ntp1 in ntp_vals and ntp2 in ntp_vals
tsync_fallback = fallback in fb_vals

# --- chrony: main config on either family plus common include directories.
chrony_hits = {}
chrony_paths = ["/etc/chrony/chrony.conf", "/etc/chrony.conf"] \
    + sorted(glob.glob("/etc/chrony/conf.d/*")) \
    + sorted(glob.glob("/etc/chrony/sources.d/*")) \
    + sorted(glob.glob("/etc/chrony.d/*"))
for path in chrony_paths:
    try:
        lines = open(path).read().splitlines()
    except OSError:
        continue
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith(("#", ";", "!", "%")):
            continue
        parts = line.split()
        if len(parts) >= 2 and parts[0] in ("server", "pool", "peer"):
            chrony_hits.setdefault(parts[1], path)
chrony_primary = ntp1 in chrony_hits and ntp2 in chrony_hits
chrony_fallback = fallback in chrony_hits

if tsync_primary:
    ev1 = f"timesyncd:{ntp_src}: NTP={' '.join(ntp_vals)}"
elif chrony_primary:
    ev1 = f"chrony:{chrony_hits[ntp1]}"
else:
    ev1 = f"timesyncd NTP={' '.join(ntp_vals) or '-'}; chrony servers={' '.join(sorted(chrony_hits)) or '-'}"
c1 = criterion("dropin_ntp_servers", tsync_primary or chrony_primary, 3,
               "persistent time sync configuration sets the required primary NTP servers", ev1)

if tsync_fallback:
    ev2 = f"timesyncd:{fb_src}: FallbackNTP={' '.join(fb_vals)}"
elif chrony_fallback:
    ev2 = f"chrony:{chrony_hits[fallback]}"
else:
    ev2 = f"timesyncd FallbackNTP={' '.join(fb_vals) or '-'}; chrony servers={' '.join(sorted(chrony_hits)) or '-'}"
c2 = criterion("dropin_fallback", tsync_fallback or chrony_fallback, 2,
               "persistent time sync configuration sets the required fallback NTP server", ev2)

units = ("systemd-timesyncd.service", "chronyd.service", "chrony.service")
enabled_unit = ""
for unit in units:
    if run("systemctl", "is-enabled", unit) == "enabled":
        enabled_unit = unit
        break
c3 = criterion("service_enabled", bool(enabled_unit), 2,
               "a time synchronization service (systemd-timesyncd or chrony) is enabled",
               enabled_unit or "no time sync service enabled")

active_unit = ""
for unit in units:
    if run("systemctl", "is-active", unit) == "active":
        active_unit = unit
        break
c4 = criterion("service_active", bool(active_unit), 1,
               "a time synchronization service (systemd-timesyncd or chrony) is active",
               active_unit or "no time sync service active")

runtime_ok = False
ev5 = "no time synchronization daemon active"
if active_unit == "systemd-timesyncd.service":
    props = {}
    for line in run("timedatectl", "show-timesync").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            props[key] = value
    system_ntp = props.get("SystemNTPServers", "").split()
    fallback_ntp = props.get("FallbackNTPServers", "").split()
    runtime_ok = ntp1 in system_ntp and ntp2 in system_ntp and fallback in fallback_ntp
    ev5 = f"timesyncd: SystemNTPServers={' '.join(system_ntp) or '-'} FallbackNTPServers={' '.join(fallback_ntp) or '-'}"
elif active_unit in ("chronyd.service", "chrony.service"):
    # Seeded hostnames never resolve, so chronyc sources cannot list them;
    # the daemon loading a config that declares all servers is the evidence.
    runtime_ok = chrony_primary and chrony_fallback
    ev5 = f"chrony: {active_unit} active; servers declared in {chrony_hits.get(ntp1, 'no config')}"
c5 = criterion("runtime_servers", runtime_ok, 2,
               "the running time sync daemon uses the configured servers", ev5)

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
