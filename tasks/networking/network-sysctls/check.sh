#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/network-sysctls","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

targets = {
    "net.ipv4.tcp_syncookies": str(p["tcp_syncookies"]),
    "net.core.somaxconn": str(p["somaxconn"]),
    "net.ipv4.tcp_fin_timeout": str(p["tcp_fin_timeout"]),
}

def active_value(key):
    try:
        return open("/proc/sys/" + key.replace(".", "/")).read().strip()
    except OSError:
        return ""

active = {key: active_value(key) for key in targets}
active_ok = all(active[key] == value for key, value in targets.items())
c1 = criterion("active_values", active_ok, 4,
               "all three kernel parameters are active on the running system",
               " ".join(f"{key}={active[key] or '?'}" for key in targets))

# Persistent effective value: systemd-sysctl precedence, last assignment wins.
def sysctl_files():
    files = {}
    for directory in ("/usr/lib/sysctl.d", "/run/sysctl.d", "/etc/sysctl.d"):
        if os.path.isdir(directory):
            for path in glob.glob(os.path.join(directory, "*.conf")):
                files[os.path.basename(path)] = path
    ordered = [files[name] for name in sorted(files)]
    if os.path.isfile("/etc/sysctl.conf") and "99-sysctl.conf" not in files:
        ordered.append("/etc/sysctl.conf")
    return ordered

persisted = {}
persisted_in_sysctl_d = {key: False for key in targets}
for path in sysctl_files():
    try:
        lines = open(path).read().splitlines()
    except OSError:
        continue
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith(("#", ";")) or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key, value = key.strip().replace("/", "."), value.strip()
        if key in targets:
            persisted[key] = (value, path)
            if path.startswith("/etc/sysctl.d/") and value == targets[key]:
                persisted_in_sysctl_d[key] = True

persist_ok = all(persisted.get(key, ("", ""))[0] == value for key, value in targets.items())
c2 = criterion("persistent_values", persist_ok, 4,
               "persistent sysctl configuration yields all three required values",
               " ".join(f"{key}={persisted.get(key, ('unset',))[0]}" for key in targets))
location_ok = all(persisted_in_sysctl_d.values())
c3 = criterion("sysctl_d_location", location_ok, 2,
               "the values are set by configuration files under /etc/sysctl.d",
               " ".join(sorted({entry[1] for entry in persisted.values() if entry[1].startswith('/etc/sysctl.d/')})) or "no file in /etc/sysctl.d sets them")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
