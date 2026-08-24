#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/tmpfs-mount","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

mount_point = p["mount_point"]
size_mib = int(p["size_mib"])
mode = int(p["mode"], 8)
expected_bytes = size_mib * 1024 * 1024

def parse_size(text):
    text = text.strip().lower()
    if not text:
        return -1
    factor = 1
    if text[-1] in "kmg":
        factor = {"k": 1024, "m": 1024 ** 2, "g": 1024 ** 3}[text[-1]]
        text = text[:-1]
    try:
        return int(float(text) * factor)
    except ValueError:
        return -1

fstype = run("findmnt", "-no", "FSTYPE", mount_point)
c1 = criterion("tmpfs_mounted", fstype == "tmpfs", 2, "tmpfs is mounted at the requested mount point", fstype or "not mounted")

actual_bytes = -1
if fstype == "tmpfs":
    stats = os.statvfs(mount_point)
    actual_bytes = stats.f_blocks * stats.f_frsize
c2 = criterion("active_size", abs(actual_bytes - expected_bytes) <= expected_bytes // 20, 2, "active tmpfs size matches the requested size", f"{actual_bytes} bytes (expected {expected_bytes})")

actual_mode = os.stat(mount_point).st_mode & 0o7777 if fstype == "tmpfs" else -1
c3 = criterion("active_mode", actual_mode == mode, 3, "mount root directory has the requested mode", f"{actual_mode:04o}" if actual_mode >= 0 else "unavailable")

persistent = False
evidence = "no matching fstab entry"
if os.path.exists("/etc/fstab"):
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 4 or fields[0].startswith("#") or fields[1] != mount_point or fields[2] != "tmpfs":
            continue
        opts = {}
        for opt in fields[3].split(","):
            key, _, value = opt.partition("=")
            opts[key] = value
        size_ok = parse_size(opts.get("size", "")) == expected_bytes
        mode_text = opts.get("mode", "")
        try:
            mode_ok = int(mode_text, 8) == mode
        except ValueError:
            mode_ok = False
        if size_ok and mode_ok:
            persistent = True
            evidence = line.strip()
            break
c4 = criterion("persistent_fstab", persistent, 3, "fstab restores the tmpfs with size and mode at boot", evidence)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
