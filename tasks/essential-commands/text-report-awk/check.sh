#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/text-report-awk","result":"error","score":0,"max_score":6,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":6,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

def read(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return None

data_path = os.path.join(p["work_dir"], p["data_file"])
report_path = os.path.join(p["work_dir"], p["report_file"])
expected_data = p["data_content"] + "\n"

totals = {}
counts = {}
for line in p["data_content"].split("\n"):
    category, value = line.split()
    totals[category] = totals.get(category, 0) + int(value)
    counts[category] = counts.get(category, 0) + 1
expected_report = "".join(
    f"{category} {totals[category]} {totals[category] / counts[category]:.2f}\n"
    for category in sorted(totals)
)

data = read(data_path)
c1 = criterion("data_intact", data == expected_data, 1,
               "data file is unmodified",
               "data unchanged" if data == expected_data else "data missing or modified")

report = read(report_path)
c2 = criterion("report_exists", report is not None and report != "", 1,
               "report file exists and is not empty",
               report_path if report else "report missing or empty")

totals_ok = False
totals_evidence = "report missing"
if report:
    seen = {}
    for line in report.splitlines():
        fields = line.split()
        if len(fields) == 3 and fields[1].lstrip("-").isdigit():
            seen[fields[0]] = int(fields[1])
    totals_ok = all(seen.get(category) == totals[category] for category in totals)
    totals_evidence = "all totals correct" if totals_ok else f"totals seen: {seen}"
c3 = criterion("totals_correct", totals_ok, 2,
               "every category is listed with the correct total", totals_evidence)

c4 = criterion("report_exact", report == expected_report, 2,
               "report matches the required format, averages and ordering exactly",
               "exact match" if report == expected_report else (report or "no report")[:200])

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 6 else "fail", "score": score, "max_score": 6, "criteria": criteria}, separators=(",", ":")))
PY
