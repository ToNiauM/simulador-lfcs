#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/grep-extract-pattern","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

log_file = p["log_file"]
out_file = p["out_file"]
prefix = p["level"] + " "

expected = []
if os.path.isfile(log_file):
    with open(log_file) as handle:
        expected = [line.rstrip("\n") for line in handle if line.startswith(prefix)]

exists = os.path.isfile(out_file)
c1 = criterion("output_exists", exists, 2, "output file exists", out_file if exists else "output file missing")

actual = []
if exists:
    with open(out_file) as handle:
        actual = [line.rstrip("\n") for line in handle if line.strip()]

missing = [line for line in expected if line not in actual]
c2 = criterion("all_matches_present", exists and not missing, 3, "every matching log line is in the output",
               "all matching lines present" if exists and not missing else f"{len(missing)} matching line(s) missing, e.g.: {missing[0] if missing else '-'}")

extras = [line for line in actual if line not in expected]
c3 = criterion("only_matches_present", exists and not extras, 3, "output contains only lines starting with the requested level",
               "no foreign lines" if exists and not extras else f"{len(extras)} unexpected line(s), e.g.: {extras[0] if extras else '-'}")

order_ok = exists and actual == expected
c4 = criterion("original_order_kept", order_ok, 2, "lines appear exactly in their original order",
               "order preserved" if order_ok else "line order or content differs from the log")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
