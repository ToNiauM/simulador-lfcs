#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/login-banner","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

banner_file = p["banner_file"]
banner_text = p["banner_text"]
motd_text = p["motd_text"]

banner_content = ""
if os.path.isfile(banner_file):
    try:
        banner_content = open(banner_file).read()
    except OSError:
        pass
banner_ok = banner_text in banner_content
c1 = criterion("banner_file_content", banner_ok, 3, "banner file contains the requested text", banner_content.strip() or f"{banner_file} missing or empty")

proc = subprocess.run(["sshd", "-T"], text=True, capture_output=True)
config_valid = proc.returncode == 0
effective_banner = ""
for line in proc.stdout.splitlines():
    fields = line.split(None, 1)
    if len(fields) == 2 and fields[0].lower() == "banner":
        effective_banner = fields[1].strip()
c2 = criterion("sshd_banner_directive", config_valid and effective_banner == banner_file, 3, "SSH daemon is configured to display the banner file before login", f"sshd -T banner: {effective_banner or 'none'}")
c3 = criterion("sshd_config_valid", config_valid, 2, "SSH daemon configuration is valid", "sshd -T succeeded" if config_valid else (proc.stderr.strip() or "sshd -T failed"))

motd_content = ""
if os.path.isfile("/etc/motd"):
    try:
        motd_content = open("/etc/motd").read()
    except OSError:
        pass
c4 = criterion("motd_content", motd_text in motd_content, 2, "message of the day contains the requested text", motd_content.strip() or "/etc/motd missing or empty")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
