#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/ssh-additional-port","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, re, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.returncode, proc.stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

port = str(p["extra_port"])

_, effective = run("/usr/sbin/sshd", "-T")
ports = [line.split()[1] for line in effective.splitlines() if line.startswith("port ")]
c1 = criterion("extra_port_effective", port in ports, 3, "effective sshd configuration includes the additional port", "ports: " + " ".join(ports) if ports else "sshd -T unavailable")
c2 = criterion("port22_kept", "22" in ports, 2, "effective sshd configuration still includes port 22", "ports: " + " ".join(ports) if ports else "sshd -T unavailable")

files = ["/etc/ssh/sshd_config"] + sorted(glob.glob("/etc/ssh/sshd_config.d/*.conf"))
persistent = False
evidence = "no Port directive for the additional port in sshd configuration files"
pattern = re.compile(r"^\s*port\s+" + re.escape(port) + r"\s*$", re.IGNORECASE)
for path in files:
    try:
        for line in open(path):
            if pattern.match(line):
                persistent = True
                evidence = f"{path}: {line.strip()}"
                break
    except OSError:
        continue
    if persistent:
        break
c3 = criterion("port_persistent", persistent, 3, "additional port is declared in a persistent sshd configuration file", evidence)

rc, _ = run("/usr/sbin/sshd", "-t")
c4 = criterion("config_valid", rc == 0, 2, "sshd configuration is syntactically valid", f"sshd -t exit code {rc}")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
