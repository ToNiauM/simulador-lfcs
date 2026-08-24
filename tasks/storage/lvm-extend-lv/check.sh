#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/lvm-extend-lv","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

vg = p["vg_name"]
lv = p["lv_name"]
fs = p["filesystem"]
target = int(p["target_size_mib"])
mount_point = p["mount_point"]
size_text = run("lvs", "--units", "m", "--nosuffix", "--noheadings", "-o", "lv_size", f"{vg}/{lv}")
try:
    lv_size = float(size_text)
except ValueError:
    lv_size = 0
c1 = criterion("lv_size", target <= lv_size < target + 5, 3, f"logical volume was extended to {target} MiB", size_text or "LV missing")
lv_path = run("lvs", "--noheadings", "-o", "lv_path", f"{vg}/{lv}")
active_source = run("findmnt", "-no", "SOURCE", "--target", mount_point)
active_fs = run("findmnt", "-no", "FSTYPE", "--target", mount_point)
mounted = bool(lv_path) and bool(active_source) and os.path.realpath(active_source) == os.path.realpath(lv_path) and active_fs == fs
c2 = criterion("mounted_filesystem", mounted, 2, "logical volume is still mounted at the requested mount point", f"{active_source or 'not mounted'} ({active_fs or '-'})")
fs_mib = 0.0
if mounted:
    stats = os.statvfs(mount_point)
    fs_mib = stats.f_blocks * stats.f_frsize / 1048576
c3 = criterion("fs_size", mounted and target * 0.85 <= fs_mib <= target + 5, 3, f"filesystem was grown to use the {target} MiB volume", f"{fs_mib:.1f} MiB" if mounted else "not mounted")
persistent = False
evidence = "no matching entry"
if lv_path and os.path.exists("/etc/fstab"):
    lv_real = os.path.realpath(lv_path)
    uuid = run("blkid", "-s", "UUID", "-o", "value", lv_path)
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 3 or fields[0].startswith("#") or fields[1] != mount_point or fields[2] != fs:
            continue
        source = fields[0]
        if (uuid and source == f"UUID={uuid}") or (not source.startswith(("UUID=", "LABEL=")) and os.path.realpath(source) == lv_real):
            persistent = True
            evidence = line.strip()
            break
c4 = criterion("persistent_fstab", persistent, 2, "fstab still restores the mount", evidence)
criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
