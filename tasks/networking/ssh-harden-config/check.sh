#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/ssh-harden-config","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, re, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.returncode, proc.stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

permit_root = p["permit_root_login"]
match_user = p["match_user"]

def effective_value(output, keyword):
    for line in output.splitlines():
        fields = line.split(None, 1)
        if len(fields) == 2 and fields[0] == keyword:
            return fields[1].strip()
    return ""

_, global_cfg = run("/usr/sbin/sshd", "-T")
actual_root = effective_value(global_cfg, "permitrootlogin")
c1 = criterion("permit_root_login", actual_root == permit_root, 3, "PermitRootLogin has the requested value", f"permitrootlogin {actual_root}" if actual_root else "sshd -T unavailable")

_, match_cfg = run("/usr/sbin/sshd", "-T", "-C", f"user={match_user},host=lab.example,addr=192.0.2.1")
actual_pa = effective_value(match_cfg, "passwordauthentication")
c2 = criterion("match_user_no_password", actual_pa == "no", 3, "password authentication is disabled for the target user", f"passwordauthentication {actual_pa} (user={match_user})" if actual_pa else "sshd -T -C unavailable")

files = ["/etc/ssh/sshd_config"] + sorted(glob.glob("/etc/ssh/sshd_config.d/*.conf"))
match_block = False
evidence = f"no 'Match User {match_user}' block in sshd configuration files"
pattern = re.compile(r"^\s*match\s+user\s+(.*)$", re.IGNORECASE)
for path in files:
    try:
        for line in open(path):
            found = pattern.match(line)
            if found and match_user in re.split(r"[,\s]+", found.group(1).strip()):
                match_block = True
                evidence = f"{path}: {line.strip()}"
                break
    except OSError:
        continue
    if match_block:
        break
c3 = criterion("match_block_persistent", match_block, 2, "a persistent Match User block targets the requested account", evidence)

rc, _ = run("/usr/sbin/sshd", "-t")
c4 = criterion("config_valid", rc == 0, 2, "sshd configuration is syntactically valid", f"sshd -t exit code {rc}")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
