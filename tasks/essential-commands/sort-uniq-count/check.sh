#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/sort-uniq-count","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import collections, json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

data_file = p["data_file"]
report_file = p["report_file"]

expected = collections.Counter()
if os.path.isfile(data_file):
    with open(data_file) as handle:
        for line in handle:
            line = line.strip()
            if line:
                expected[line] += 1

exists = os.path.isfile(report_file)
c1 = criterion("report_exists", exists, 2, "report file exists", report_file if exists else "report file missing")

# Parse "<count> <name>" tolerating any leading/inner whitespace (uniq -c style).
entries, malformed = [], []
if exists:
    with open(report_file) as handle:
        for line in handle:
            if not line.strip():
                continue
            fields = line.split()
            if len(fields) == 2 and fields[0].isdigit():
                entries.append((int(fields[0]), fields[1]))
            else:
                malformed.append(line.strip())

actual_counts = {name: count for count, name in entries}
counts_ok = (exists and not malformed and len(entries) == len(actual_counts)
             and actual_counts == dict(expected))
diff = sorted(set(expected) ^ set(actual_counts)) + [n for n in expected if n in actual_counts and actual_counts[n] != expected[n]]
c2 = criterion("counts_correct", counts_ok, 4, "each distinct username appears once with its exact count",
               "all counts correct" if counts_ok else ("malformed lines: " + "; ".join(malformed) if malformed else "wrong entries: " + ", ".join(diff) if diff else "duplicate or missing entries"))

order_ok = exists and entries == sorted(entries, key=lambda item: item[0], reverse=True)
c3 = criterion("descending_order", exists and bool(entries) and order_ok, 4, "report lines are sorted by count in descending order",
               "descending order" if entries and order_ok else "counts are not in descending order" if entries else "no parseable lines")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
