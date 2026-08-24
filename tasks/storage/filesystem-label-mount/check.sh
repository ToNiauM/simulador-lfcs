#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/filesystem-label-mount","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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
label = p["fs_label"]
expected_size = int(p["part_size_mib"])
mount_point = p["mount_point"]
try:
    table = json.loads(run("sfdisk", "-J", disk)).get("partitiontable", {})
except (ValueError, TypeError):
    table = {}
sector = int(table.get("sectorsize", 512) or 512)
parts = sorted(table.get("partitions", []), key=lambda item: item.get("start", 0))
sizes = [round(item.get("size", 0) * sector / 1048576, 1) for item in parts]
part_ok = table.get("label", "") == "gpt" and len(parts) >= 1 and abs(sizes[0] - expected_size) <= 4
c1 = criterion("gpt_partition", part_ok, 2, f"GPT partition of {expected_size} MiB exists on the task disk", f"label={table.get('label') or 'none'} sizes={sizes}")
device = ""
for item in parts:
    node = item.get("node", "")
    if node and run("blkid", "-s", "LABEL", "-o", "value", node) == label:
        device = node
        break
device_fs = run("blkid", "-s", "TYPE", "-o", "value", device) if device else ""
c2 = criterion("labeled_filesystem", bool(device) and device_fs == fs, 3, f"{fs} filesystem labeled {label} exists on the task disk", f"{device} ({device_fs})" if device else f"no filesystem labeled {label}")
fstab_ok = False
evidence = "no matching entry"
if os.path.exists("/etc/fstab"):
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 3 or fields[0].startswith("#") or fields[1] != mount_point or fields[2] != fs:
            continue
        if fields[0] == f"LABEL={label}":
            fstab_ok = True
            evidence = line.strip()
            break
c3 = criterion("fstab_label_entry", fstab_ok, 3, "fstab mounts the filesystem by its label", evidence)
active_source = run("findmnt", "-no", "SOURCE", "--target", mount_point)
active_fs = run("findmnt", "-no", "FSTYPE", "--target", mount_point)
mounted = bool(device) and bool(active_source) and os.path.realpath(active_source) == os.path.realpath(device) and active_fs == fs
c4 = criterion("mounted_filesystem", mounted, 2, "labeled filesystem is mounted at the requested mount point", f"{active_source or 'not mounted'} ({active_fs or '-'})")
criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
