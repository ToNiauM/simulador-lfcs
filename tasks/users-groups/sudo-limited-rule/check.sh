#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"users-groups/sudo-limited-rule","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, re, stat, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

username = p["username"]
command = p["allowed_command"]
path = p["sudoers_file"]
exists = os.path.isfile(path)
mode_ok = False
mode_text = "file missing"
if exists:
    mode = stat.S_IMODE(os.stat(path).st_mode)
    mode_ok = (mode & 0o022) == 0  # not writable by group/other, as sudo requires
    mode_text = oct(mode)
c1 = criterion("file_present", exists and mode_ok, 2, "sudoers drop-in file exists with permissions accepted by sudo", mode_text)
valid = subprocess.run(["visudo", "-c", "-q", "-f", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0 if exists else False
c2 = criterion("syntax_valid", valid, 2, "sudoers file passes visudo validation", "visudo -c exit 0" if valid else "visudo validation failed")
rule_line = ""
grants_command = nopasswd = only_command = False
if exists:
    for raw in open(path):
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith("Defaults"):
            continue
        match = re.match(rf"^{re.escape(username)}\s+ALL\s*=\s*(\((?:root|ALL)(?::\w+)?\)\s*)?(.*)$", line)
        if not match:
            continue
        rule_line = line
        spec = match.group(2)
        nopasswd = "NOPASSWD:" in spec
        commands = [c.strip() for c in re.sub(r"(NOPASSWD|PASSWD|NOEXEC|SETENV):", "", spec).split(",") if c.strip()]
        grants_command = any(c == command or c.startswith(command + " ") for c in commands)
        only_command = grants_command and len(commands) == 1 and "ALL" not in commands
        if grants_command:
            break
c3 = criterion("rule_grants_command", grants_command, 3, "rule allows the user to run the required command as root", rule_line or "no matching rule for user")
c4 = criterion("no_password", nopasswd, 2, "rule works without password (NOPASSWD)", rule_line or "no matching rule for user")
c5 = criterion("least_privilege", only_command, 1, "rule grants no command beyond the required one", rule_line or "no matching rule for user")
criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
