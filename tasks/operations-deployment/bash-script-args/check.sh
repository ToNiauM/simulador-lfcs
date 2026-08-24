#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/bash-script-args","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import hashlib, json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

script_path = p["script_path"]
expected_argc = int(p["expected_argc"])
error_exit_code = int(p["error_exit_code"])

# Deterministic test vectors derived from the task seed.
digest = hashlib.sha256(payload["seed"].encode()).hexdigest()
case_a = [f"alpha{digest[20 + i * 2:22 + i * 2]}" for i in range(expected_argc)]
case_b = [f"zulu-{digest[30 + i * 2:32 + i * 2]}" for i in range(expected_argc)]

exists = os.path.isfile(script_path)
executable = exists and os.access(script_path, os.X_OK)
c1 = criterion("script_executable", executable, 2, "script exists and is executable", script_path if executable else f"{script_path} missing or not executable")

def run_script(args):
    if not executable:
        return None
    try:
        return subprocess.run([script_path] + args, text=True, capture_output=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return None

wrong_ok = False
wrong_evidence = "script not runnable"
proc_zero = run_script([])
proc_extra = run_script(case_a + ["extra"])
if proc_zero is not None and proc_extra is not None:
    wrong_ok = (proc_zero.returncode == error_exit_code and proc_zero.stdout == ""
                and proc_extra.returncode == error_exit_code and proc_extra.stdout == "")
    wrong_evidence = f"0 args -> rc={proc_zero.returncode}; {expected_argc + 1} args -> rc={proc_extra.returncode} (expected {error_exit_code}, empty stdout)"
c2 = criterion("wrong_arg_count", wrong_ok, 2, "wrong argument count exits with the requested status code", wrong_evidence)

def check_case(args):
    proc = run_script(args)
    if proc is None:
        return False, "script not runnable"
    expected_lines = [a.upper() for a in reversed(args)]
    actual_lines = proc.stdout.rstrip("\n").split("\n") if proc.stdout.strip() else []
    ok = proc.returncode == 0 and actual_lines == expected_lines
    return ok, f"args={' '.join(args)} rc={proc.returncode} stdout={proc.stdout.strip()!r}"

ok_a, ev_a = check_case(case_a)
c3 = criterion("transform_case_one", ok_a, 3, "correct invocation prints reversed uppercase arguments (test case 1)", ev_a)
ok_b, ev_b = check_case(case_b)
c4 = criterion("transform_case_two", ok_b, 3, "correct invocation prints reversed uppercase arguments (test case 2)", ev_b)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
