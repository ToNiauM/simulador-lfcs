#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/rsyslog-custom-facility","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

facility = p["facility"]
conf_file = p["conf_file"]
log_file = p["log_file"]
token = p["test_token"]

# Accept classic selector syntax and RainerScript alike: an uncommented line
# mentioning the facility and the destination file.
rule_ok = False
rule_evidence = f"{conf_file} missing"
if os.path.isfile(conf_file):
    rule_evidence = f"no rule for {facility} -> {log_file} found"
    for line in open(conf_file):
        text = line.split("#", 1)[0]
        if facility in text and log_file in text:
            rule_ok = True
            rule_evidence = line.strip()
            break
c1 = criterion("rsyslog_rule", rule_ok, 3, "rsyslog rule routes the facility to the dedicated file", rule_evidence)

active = run("systemctl", "is-active", "rsyslog")
c2 = criterion("rsyslog_active", active == "active", 2, "rsyslog service is running", active or "unknown")

exists = os.path.isfile(log_file) and os.path.getsize(log_file) > 0
c3 = criterion("log_file_written", exists, 2, "dedicated log file exists and is not empty", log_file if exists else f"{log_file} missing or empty")

token_ok = False
if exists:
    token_ok = token in open(log_file, errors="replace").read()
c4 = criterion("test_message_logged", token_ok, 3, "test message with the required token reached the file", token if token_ok else f"token {token} not found")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
