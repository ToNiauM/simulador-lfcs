#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/journal-size-limit","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.returncode, proc.stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

dropin_file = p["dropin_file"]
expected = {"systemmaxuse": p["system_max_use"].lower(), "maxretentionsec": p["max_retention_sec"].lower()}

found = {}
file_evidence = f"{dropin_file} missing"
if os.path.isfile(dropin_file):
    section = ""
    for line in open(dropin_file):
        text = line.split("#", 1)[0].strip()
        if not text:
            continue
        if text.startswith("[") and text.endswith("]"):
            section = text[1:-1].strip().lower()
            continue
        if section == "journal" and "=" in text:
            key, value = (part.strip() for part in text.split("=", 1))
            found[key.lower()] = value
    file_evidence = "; ".join(f"{k}={v}" for k, v in sorted(found.items())) or "no [Journal] settings found"

max_use_ok = found.get("systemmaxuse", "").lower() == expected["systemmaxuse"]
c1 = criterion("system_max_use", max_use_ok, 3, "drop-in caps journal disk usage (SystemMaxUse)", file_evidence)

retention_ok = found.get("maxretentionsec", "").lower() == expected["maxretentionsec"]
c2 = criterion("max_retention", retention_ok, 3, "drop-in caps journal retention (MaxRetentionSec)", file_evidence)

rc, usage = run("journalctl", "--disk-usage")
c3 = criterion("journalctl_functional", rc == 0 and bool(usage), 2, "journalctl --disk-usage works", usage or f"exit code {rc}")

_, active = run("systemctl", "is-active", "systemd-journald")
c4 = criterion("journald_active", active == "active", 2, "systemd-journald is running", active or "unknown")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
