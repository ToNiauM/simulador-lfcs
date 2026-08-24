#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/bind-mount-persistent","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

src = p["source_dir"]
target = p["bind_target"]
sentinel = p["sentinel_file"]
expected = p["sentinel_content"]

mounted_target = run("findmnt", "-no", "TARGET", target)
c1 = criterion("bind_active", mounted_target == target, 3, "target directory is an active mount point", mounted_target or "not a mount point")

content = ""
try:
    with open(os.path.join(target, sentinel)) as handle:
        content = handle.read().strip()
except OSError:
    pass
c2 = criterion("content_visible", content == expected, 3, "source data is visible at the bind target", content or "sentinel file unreadable")

persistent = False
evidence = "no matching fstab entry"
src_real = os.path.realpath(src)
if os.path.exists("/etc/fstab"):
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 4 or fields[0].startswith("#") or fields[1] != target:
            continue
        options = fields[3].split(",")
        if os.path.realpath(fields[0]) == src_real and ("bind" in options or "rbind" in options or fields[2] in ("bind", "rbind")):
            persistent = True
            evidence = line.strip()
            break
c3 = criterion("persistent_fstab", persistent, 4, "fstab restores the bind mount at boot", evidence)

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
