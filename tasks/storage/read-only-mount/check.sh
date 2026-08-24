#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/read-only-mount","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

disk = p["target_disk"]
fs = p["filesystem"]
mount_point = p["mount_point"]

def resolve_source(source):
    if source.startswith("UUID="):
        return os.path.realpath(run("blkid", "-U", source[5:]) or "/nonexistent")
    if source.startswith("LABEL="):
        return os.path.realpath(run("blkid", "-L", source[6:]) or "/nonexistent")
    if source.startswith("PARTUUID=") or source.startswith("PARTLABEL="):
        return os.path.realpath(run("blkid", "-o", "device", "-t", source) or "/nonexistent")
    return os.path.realpath(source)

mounted_fs = run("findmnt", "-no", "FSTYPE", mount_point)
mounted_src = run("findmnt", "-no", "SOURCE", mount_point)
mounted_ok = mounted_fs == fs and bool(mounted_src) and os.path.realpath(mounted_src).startswith(disk)
c1 = criterion("mounted_filesystem", mounted_ok, 3, "filesystem from the task disk is mounted at the requested mount point", f"{mounted_src or 'not mounted'} ({mounted_fs or '-'})")

options = run("findmnt", "-no", "OPTIONS", mount_point)
readonly = mounted_ok and "ro" in options.split(",")
c2 = criterion("readonly_active", readonly, 3, "active mount is read-only", options or "no mount options found")

persistent = False
evidence = "no matching fstab entry"
if os.path.exists("/etc/fstab"):
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 4 or fields[0].startswith("#") or fields[1] != mount_point or fields[2] != fs:
            continue
        if "ro" in fields[3].split(",") and resolve_source(fields[0]).startswith(disk):
            persistent = True
            evidence = line.strip()
            break
c3 = criterion("persistent_fstab", persistent, 4, "fstab restores the read-only mount at boot", evidence)

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
