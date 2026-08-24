#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/sysctl-ip-forward","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

sysctl_file = p["sysctl_file"]
KEY = "net.ipv4.ip_forward"

active = open("/proc/sys/net/ipv4/ip_forward").read().strip()
c1 = criterion("forwarding_active", active == "1", 4, "IPv4 forwarding is active", f"{KEY} = {active}")

def last_value(path):
    value = None
    try:
        for line in open(path):
            line = line.strip()
            if not line or line[0] in "#;":
                continue
            if "=" in line:
                key, _, raw = line.partition("=")
                if key.strip() == KEY:
                    value = raw.strip()
    except OSError:
        pass
    return value

file_value = last_value(sysctl_file) if os.path.isfile(sysctl_file) else None
c2 = criterion("persistent_file", file_value == "1", 4, "requested sysctl.d file enables forwarding persistently", f"{sysctl_file}: {KEY} = {file_value}" if file_value is not None else f"{sysctl_file} missing or without {KEY}")

# Effective boot-time value: emulate sysctl --system ordering (unique basename,
# earlier directories win; lexical order; /etc/sysctl.conf applied last).
dirs = ("/run/sysctl.d", "/etc/sysctl.d", "/usr/local/lib/sysctl.d", "/usr/lib/sysctl.d", "/lib/sysctl.d")
chosen = {}
for directory in dirs:
    for path in glob.glob(os.path.join(directory, "*.conf")):
        chosen.setdefault(os.path.basename(path), path)
effective = None
origin = "no sysctl configuration sets the key"
for name in sorted(chosen):
    value = last_value(chosen[name])
    if value is not None:
        effective = value
        origin = f"{chosen[name]}: {KEY} = {value}"
if os.path.isfile("/etc/sysctl.conf"):
    value = last_value("/etc/sysctl.conf")
    if value is not None:
        effective = value
        origin = f"/etc/sysctl.conf: {KEY} = {value}"
c3 = criterion("no_override", effective == "1", 2, "no later sysctl configuration overrides forwarding at boot", origin)

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
