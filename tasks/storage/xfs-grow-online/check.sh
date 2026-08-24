#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/xfs-grow-online","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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
mount_point = p["mount_point"]
initial = int(p["initial_size_mib"])
target = int(p["target_size_mib"])

size_text = run("lvs", "--units", "m", "--nosuffix", "--noheadings", "-o", "lv_size", f"{vg}/{lv}")
try:
    lv_size = float(size_text)
except ValueError:
    lv_size = 0
c1 = criterion("lv_size", target <= lv_size < target + 5, 3, "logical volume was extended to the requested size", size_text or "LV missing")

lv_path = run("lvs", "--noheadings", "-o", "lv_path", f"{vg}/{lv}")
mounted_fs = run("findmnt", "-no", "FSTYPE", mount_point)
mounted_src = run("findmnt", "-no", "SOURCE", mount_point)
mounted_ok = mounted_fs == fs and bool(lv_path) and bool(mounted_src) and os.path.realpath(mounted_src) == os.path.realpath(lv_path)
c2 = criterion("mounted_filesystem", mounted_ok, 2, "xfs filesystem on the logical volume is mounted", f"{mounted_src or 'not mounted'} ({mounted_fs or '-'})")

fs_mib = 0
if mounted_ok:
    stats = os.statvfs(mount_point)
    fs_mib = stats.f_blocks * stats.f_frsize / (1024 * 1024)
c3 = criterion("fs_grown", fs_mib > initial and fs_mib >= target * 0.75, 3, "filesystem was grown to use the new space", f"{fs_mib:.0f} MiB visible (target {target} MiB)")

persistent = False
evidence = "no matching fstab entry"
if lv_path and os.path.exists("/etc/fstab"):
    lv_real = os.path.realpath(lv_path)
    uuid = run("blkid", "-s", "UUID", "-o", "value", lv_path)
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 3 or fields[0].startswith("#") or fields[1] != mount_point or fields[2] != fs:
            continue
        source = fields[0]
        if source == f"UUID={uuid}" or (not source.startswith(("UUID=", "LABEL=", "PARTUUID=", "PARTLABEL=")) and os.path.realpath(source) == lv_real):
            persistent = True
            evidence = line.strip()
            break
c4 = criterion("persistent_fstab", persistent, 2, "fstab keeps the mount persistent across reboots", evidence)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
