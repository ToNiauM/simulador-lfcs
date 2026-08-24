#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/ext4-quota-user","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

disk = p["target_disk"]
fs = p["filesystem"]
user = p["username"]
hard = int(p["block_hard_kib"])
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
options = run("findmnt", "-no", "OPTIONS", mount_point).split(",")
mounted_ok = mounted_fs == fs and bool(mounted_src) and os.path.realpath(mounted_src).startswith(disk) and ("usrquota" in options or "quota" in options)
c1 = criterion("mounted_with_usrquota", mounted_ok, 2, "filesystem from the task disk is mounted with the usrquota option", f"{mounted_src or 'not mounted'} ({','.join(options) if options != [''] else '-'})")

persistent = False
evidence = "no matching fstab entry"
if os.path.exists("/etc/fstab"):
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 4 or fields[0].startswith("#") or fields[1] != mount_point or fields[2] != fs:
            continue
        if "usrquota" in fields[3].split(",") and resolve_source(fields[0]).startswith(disk):
            persistent = True
            evidence = line.strip()
            break
c2 = criterion("persistent_fstab", persistent, 2, "fstab restores the mount with usrquota at boot", evidence)

report = subprocess.run(["quotaon", "-up", mount_point], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout.strip()
quota_on = "is on" in report
c3 = criterion("quota_enabled", quota_on, 3, "user quota accounting and enforcement is enabled", report or "quotaon state unavailable")

limit_ok = False
evidence = f"no repquota entry for {user}"
repquota = run("repquota", "-u", mount_point)
for line in repquota.splitlines():
    fields = line.split()
    if len(fields) >= 5 and fields[0] == user:
        evidence = line.strip()
        try:
            limit_ok = int(fields[4]) == hard
        except ValueError:
            limit_ok = False
        break
c4 = criterion("user_block_limit", limit_ok, 3, "hard block limit for the user matches the requested value", evidence)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
