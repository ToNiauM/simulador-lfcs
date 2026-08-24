#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/find-large-files","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, sys, time

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

base = p["base_dir"]
report = p["report_file"]
threshold_bytes = int(p["threshold_kib"]) * 1024
age_seconds = int(p["age_days"]) * 86400
cutoff = time.time() - age_seconds

expected = set()
for root, _dirs, files in os.walk(base):
    for name in files:
        path = os.path.join(root, name)
        try:
            st = os.lstat(path)
        except OSError:
            continue
        if os.path.isfile(path) and not os.path.islink(path):
            if st.st_size > threshold_bytes and st.st_mtime < cutoff:
                expected.add(path)

exists = os.path.isfile(report)
c1 = criterion("report_exists", exists, 2, "report file exists", report if exists else "report file missing")

actual = []
if exists:
    with open(report) as handle:
        actual = [line.rstrip("\n") for line in handle if line.strip()]
actual_set = set(actual)

missing = sorted(expected - actual_set)
c2 = criterion("all_matches_listed", exists and not missing, 3,
               "every file matching both conditions is listed",
               "all matching files listed" if exists and not missing else "missing: " + ", ".join(missing) if missing else "report file missing")
extras = sorted(actual_set - expected)
c3 = criterion("no_extra_entries", exists and not extras, 3,
               "report lists only files matching both conditions",
               "no extra entries" if exists and not extras else "extra: " + ", ".join(extras) if extras else "report file missing")
sorted_ok = exists and actual == sorted(actual) and len(actual) == len(actual_set)
c4 = criterion("alphabetical_order", sorted_ok, 2,
               "entries are unique and in alphabetical order",
               "order ok" if sorted_ok else "entries out of order or duplicated" if exists else "report file missing")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
