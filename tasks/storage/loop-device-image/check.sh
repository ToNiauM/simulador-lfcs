#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/loop-device-image","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, stat, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

image = p["image_path"]
size_mib = int(p["size_mib"])
fs = p["filesystem"]
mount_point = p["mount_point"]
expected_bytes = size_mib * 1024 * 1024

image_ok = False
evidence = "image file missing"
try:
    info = os.stat(image)
    image_ok = stat.S_ISREG(info.st_mode) and expected_bytes <= info.st_size <= expected_bytes + 8 * 1024 * 1024
    evidence = f"{info.st_size} bytes (expected {expected_bytes})"
except OSError:
    pass
c1 = criterion("image_file", image_ok, 2, "image file exists with the requested size", evidence)

mounted_fs = run("findmnt", "-no", "FSTYPE", mount_point)
mounted_src = run("findmnt", "-no", "SOURCE", mount_point)
loop_ok = False
evidence = f"{mounted_src or 'not mounted'} ({mounted_fs or '-'})"
if mounted_fs == fs and mounted_src:
    src_real = os.path.realpath(mounted_src)
    backing = ""
    if src_real.startswith("/dev/loop"):
        backing = run("losetup", "-nO", "BACK-FILE", src_real).replace(" (deleted)", "").strip()
    if backing and os.path.realpath(backing) == os.path.realpath(image):
        loop_ok = True
        evidence = f"{src_real} backed by {backing}"
c2 = criterion("loop_mounted", loop_ok, 4, "image is mounted at the requested mount point via a loop device", evidence)

persistent = False
evidence = "no matching fstab entry"
if os.path.exists("/etc/fstab"):
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 4 or fields[0].startswith("#") or fields[1] != mount_point or fields[2] != fs:
            continue
        options = fields[3].split(",")
        has_loop = any(opt == "loop" or opt.startswith("loop=") for opt in options)
        if has_loop and os.path.realpath(fields[0]) == os.path.realpath(image):
            persistent = True
            evidence = line.strip()
            break
c3 = criterion("persistent_fstab", persistent, 4, "fstab restores the loop mount at boot", evidence)

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
