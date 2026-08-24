#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/listening-services-inventory","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.stdout
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

report_path = p["report_path"]
port_a = int(p["port_a"])
port_b = int(p["port_b"])

lines = []
numeric = False
if os.path.isfile(report_path):
    lines = [line.strip() for line in open(report_path) if line.strip()]
    numeric = bool(lines) and all(line.isdigit() for line in lines)
c1 = criterion("report_format", numeric, 2,
               "report file exists and contains only one port number per line",
               " ".join(lines[:20]) if lines else "file missing or empty")

ports = [int(line) for line in lines] if numeric else []
ordered = numeric and ports == sorted(set(ports))
c2 = criterion("sorted_unique", ordered, 2,
               "ports are in ascending order without duplicates",
               " ".join(str(x) for x in ports[:20]) or "no ports parsed")

has_fixtures = port_a in ports and port_b in ports
c3 = criterion("fixture_ports", has_fixtures, 3,
               "both test service ports appear in the report",
               f"expected {port_a} and {port_b}; report has {sorted(set(ports) & {port_a, port_b}) or 'neither'}")

actual = set()
for line in run("ss", "-H", "-tln").splitlines():
    fields = line.split()
    if len(fields) >= 4 and ":" in fields[3]:
        port_text = fields[3].rsplit(":", 1)[1]
        if port_text.isdigit():
            actual.add(int(port_text))
complete = numeric and actual and set(ports) == actual
missing = sorted(actual - set(ports))
extra = sorted(set(ports) - actual)
c4 = criterion("matches_actual", complete, 3,
               "report matches the full set of TCP ports currently listening",
               f"missing:{missing} extra:{extra}" if ports else "no report data")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
