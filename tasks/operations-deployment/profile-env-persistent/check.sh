#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/profile-env-persistent","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

var_name = p["var_name"]
var_value = p["var_value"]
script_path = p["script_path"]

exists = os.path.isfile(script_path)
executable = exists and os.access(script_path, os.X_OK)
c1 = criterion("script_executable", executable, 2, "profile script exists and is executable", oct(os.stat(script_path).st_mode & 0o777) if exists else "script missing")

syntax_ok = False
syntax_evidence = "script missing"
if exists:
    proc = subprocess.run(["bash", "-n", script_path], text=True, capture_output=True)
    syntax_ok = proc.returncode == 0
    syntax_evidence = "bash -n: syntax OK" if syntax_ok else (proc.stderr.strip() or "bash -n failed")
c2 = criterion("script_syntax", syntax_ok, 2, "profile script has valid shell syntax", syntax_evidence)

sourced_value = ""
if exists:
    proc = subprocess.run(
        ["env", "-i", "bash", "-c", f'. "$1" >/dev/null 2>&1; printf "%s" "${{{var_name}:-}}"', "bash", script_path],
        text=True, capture_output=True)
    sourced_value = proc.stdout
c3 = criterion("script_sets_variable", sourced_value == var_value, 3, "sourcing the script sets the requested variable and value", f"{var_name}={sourced_value or '(empty)'}")

proc = subprocess.run(["bash", "-lc", f'printf "%s" "${{{var_name}:-}}"'], text=True, capture_output=True)
login_value = proc.stdout
c4 = criterion("login_shell_value", login_value == var_value, 3, "login shells receive the variable with the requested value", f"{var_name}={login_value or '(empty)'}")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
