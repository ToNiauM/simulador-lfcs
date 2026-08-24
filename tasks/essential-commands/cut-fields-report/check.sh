#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/cut-fields-report","result":"error","score":0,"max_score":5,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":5,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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

source_path = os.path.join(p["work_dir"], p["source_file"])
output_path = os.path.join(p["work_dir"], p["output_file"])
expected_source = p["csv_content"] + "\n"
delimiter = p["delimiter"]
indexes = [int(field) - 1 for field in p["fields"].split(",")]
expected_output = "\n".join(
    delimiter.join(parts[i] for i in indexes if i < len(parts))
    for parts in (line.split(delimiter) for line in p["csv_content"].split("\n"))
) + "\n"

source_data = read(source_path)
c1 = criterion("source_intact", source_data == expected_source, 2,
               "source file is unmodified",
               "source unchanged" if source_data == expected_source else ("source missing" if source_data is None else "source content differs"))
output_data = read(output_path)
c2 = criterion("output_exists", output_data is not None and output_data != "", 1,
               "output file exists and is not empty",
               output_path if output_data else "output file missing or empty")
c3 = criterion("output_content", output_data == expected_output, 2,
               "output contains exactly the requested columns",
               "content matches" if output_data == expected_output else (output_data or "no output")[:200])

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 5 else "fail", "score": score, "max_score": 5, "criteria": criteria}, separators=(",", ":")))
PY
