#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/hostname-and-hosts","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

hostname = p["new_hostname"]

active = open("/proc/sys/kernel/hostname").read().strip()
c1 = criterion("hostname_active", active == hostname, 2, "active hostname matches the requested name", active or "unavailable")

static = ""
if os.path.isfile("/etc/hostname"):
    static = open("/etc/hostname").read().strip()
c2 = criterion("hostname_static", static == hostname, 2, "static hostname in /etc/hostname persists across reboots", static or "/etc/hostname missing")

def hosts_entry(ip, fqdn, short):
    if not os.path.isfile("/etc/hosts"):
        return False, "/etc/hosts missing"
    for line in open("/etc/hosts"):
        fields = line.split("#", 1)[0].split()
        if len(fields) >= 2 and fields[0] == ip and fqdn in fields[1:] and short in fields[1:]:
            return True, line.strip()
    return False, f"no entry mapping {fqdn} and {short} to {ip}"

ok_a, ev_a = hosts_entry(p["ip_a"], p["fqdn_a"], p["host_a"])
c3 = criterion("hosts_entry_a", ok_a, 2, "first host entry present in /etc/hosts", ev_a)
ok_b, ev_b = hosts_entry(p["ip_b"], p["fqdn_b"], p["host_b"])
c4 = criterion("hosts_entry_b", ok_b, 2, "second host entry present in /etc/hosts", ev_b)

resolved = run("getent", "hosts", p["fqdn_a"])
c5 = criterion("resolution_active", resolved.split()[:1] == [p["ip_a"]], 2, "fully qualified name resolves to the requested address", resolved or "name does not resolve")

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
