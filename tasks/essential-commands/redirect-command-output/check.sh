#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/redirect-command-output","result":"error","score":0,"max_score":5,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":5,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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

program = p["program_path"]
stdout_path = os.path.join(p["output_dir"], p["stdout_file"])
stderr_path = os.path.join(p["output_dir"], p["stderr_file"])
expected_stdout = p["stdout_content"] + "\n"
expected_stderr = p["stderr_content"] + "\n"

program_ok = os.path.isfile(program) and os.access(program, os.X_OK)
c1 = criterion("program_intact", program_ok, 1,
               "provided program is still present and executable",
               program if program_ok else "program missing or not executable")
stdout_data = read(stdout_path)
c2 = criterion("stdout_captured", stdout_data == expected_stdout, 2,
               "stdout file contains exactly the standard output stream",
               "stdout matches" if stdout_data == expected_stdout else ("file missing" if stdout_data is None else stdout_data[:200]))
stderr_data = read(stderr_path)
c3 = criterion("stderr_captured", stderr_data == expected_stderr, 2,
               "stderr file contains exactly the standard error stream",
               "stderr matches" if stderr_data == expected_stderr else ("file missing" if stderr_data is None else stderr_data[:200]))

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 5 else "fail", "score": score, "max_score": 5, "criteria": criteria}, separators=(",", ":")))
PY
