#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/sshd-match-restrictions","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, shutil, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

user = p["restricted_user"]
command = p["forced_command"]
sshd = shutil.which("sshd") or "/usr/sbin/sshd"

def effective_config(*extra):
    conf = {}
    for line in run(sshd, "-T", *extra).splitlines():
        parts = line.split(None, 1)
        if parts:
            conf[parts[0].lower()] = parts[1].strip() if len(parts) > 1 else ""
    return conf

passwd = run("getent", "passwd", user)
c1 = criterion("user_exists", bool(passwd), 1, "restricted user account exists", passwd or "account missing")

matched = effective_config("-C", f"user={user},host=lfcs.example,addr=127.0.0.1")
c2 = criterion("forced_command", matched.get("forcecommand", "") == command, 3,
               "effective sshd config forces the required command for the user",
               f"forcecommand={matched.get('forcecommand', 'unavailable')}")
c3 = criterion("no_tcp_forwarding", matched.get("allowtcpforwarding", "") == "no", 3,
               "TCP forwarding is disabled for the restricted user",
               f"allowtcpforwarding={matched.get('allowtcpforwarding', 'unavailable')}")

base = effective_config()
base_ok = base.get("forcecommand", "") == "none" and base.get("allowtcpforwarding", "") == "yes"
c4 = criterion("defaults_untouched", base_ok, 2,
               "default SSH behavior is unchanged for other accounts",
               f"forcecommand={base.get('forcecommand', 'unavailable')} allowtcpforwarding={base.get('allowtcpforwarding', 'unavailable')}")

states = {unit: run("systemctl", "is-active", unit) for unit in ("ssh.service", "ssh.socket", "sshd.service")}
c5 = criterion("ssh_available", "active" in states.values(), 1,
               "SSH service is running",
               " ".join(f"{unit}={state or 'unknown'}" for unit, state in states.items()))

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
