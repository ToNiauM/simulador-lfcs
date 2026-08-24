#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/journald-persistent","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

dropin = p["dropin_file"]

storage = None
evidence1 = "file not found"
if os.path.isfile(dropin):
    section = None
    for raw in open(dropin):
        line = raw.strip()
        if not line or line.startswith(("#", ";")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section == "Journal" and "=" in line:
            key, value = (part.strip() for part in line.split("=", 1))
            if key == "Storage":
                storage = value
    evidence1 = f"Storage={storage}" if storage else "no Storage= under [Journal]"
c1 = criterion("dropin_config", storage == "persistent", 4,
               "drop-in file sets journal storage to persistent", evidence1)

journal_dir = "/var/log/journal"
c2 = criterion("journal_dir", os.path.isdir(journal_dir), 3,
               "persistent journal directory exists", journal_dir if os.path.isdir(journal_dir) else "directory missing")

journal_files = []
if os.path.isdir(journal_dir):
    for root, _dirs, files in os.walk(journal_dir):
        journal_files.extend(os.path.join(root, name) for name in files if name.endswith(".journal"))
c3 = criterion("journald_writes_disk", bool(journal_files), 3,
               "journald is writing journal files to disk", journal_files[0] if journal_files else "no .journal files on disk")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
