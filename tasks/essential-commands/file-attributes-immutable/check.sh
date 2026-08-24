#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/file-attributes-immutable","result":"error","score":0,"max_score":6,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":6,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

def flags_of(path):
    proc = subprocess.run(["lsattr", "-d", path], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if proc.returncode != 0 or not proc.stdout.strip():
        return None
    return proc.stdout.split()[0]

def read(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return None

immutable_path = os.path.join(p["work_dir"], p["immutable_file"])
append_path = os.path.join(p["work_dir"], p["append_file"])

imm_flags = flags_of(immutable_path)
imm_ok = imm_flags is not None and "i" in imm_flags
c1 = criterion("immutable_attribute", imm_ok, 2,
               "config file carries the immutable attribute",
               imm_flags if imm_flags is not None else "file missing or lsattr unavailable")

imm_data = read(immutable_path)
imm_intact = imm_data == p["immutable_content"] + "\n"
c2 = criterion("immutable_content_intact", imm_intact, 1,
               "config file content is unchanged",
               "content unchanged" if imm_intact else "content differs or file unreadable")

app_flags = flags_of(append_path)
app_ok = app_flags is not None and "a" in app_flags
c3 = criterion("append_only_attribute", app_ok, 2,
               "log file carries the append-only attribute",
               app_flags if app_flags is not None else "file missing or lsattr unavailable")

app_data = read(append_path)
app_intact = app_data is not None and app_data.startswith(p["append_content"] + "\n")
c4 = criterion("append_content_intact", app_intact, 1,
               "existing log content is preserved",
               "original content preserved" if app_intact else "original content altered or file unreadable")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 6 else "fail", "score": score, "max_score": 6, "criteria": criteria}, separators=(",", ":")))
PY
