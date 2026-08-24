#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/ext4-partition-mount","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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
expected_size = int(p["part_size_mib"])
mount_point = p["mount_point"]
option = p["mount_option"]
try:
    table = json.loads(run("sfdisk", "-J", disk)).get("partitiontable", {})
except (ValueError, TypeError):
    table = {}
sector = int(table.get("sectorsize", 512) or 512)
parts = sorted(table.get("partitions", []), key=lambda item: item.get("start", 0))
sizes = [round(item.get("size", 0) * sector / 1048576, 1) for item in parts]
part_ok = table.get("label", "") == "gpt" and len(parts) >= 1 and abs(sizes[0] - expected_size) <= 4
c1 = criterion("gpt_partition", part_ok, 2, f"GPT partition of {expected_size} MiB exists on the task disk", f"label={table.get('label') or 'none'} sizes={sizes}")
active_source = run("findmnt", "-no", "SOURCE", "--target", mount_point)
active_fs = run("findmnt", "-no", "FSTYPE", "--target", mount_point)
source_on_disk = bool(active_source) and os.path.realpath(active_source).startswith(disk)
c2 = criterion("mounted_filesystem", source_on_disk and active_fs == fs, 3, "filesystem from the task disk is mounted at the requested mount point", f"{active_source or 'not mounted'} ({active_fs or '-'})")
active_options = run("findmnt", "-no", "OPTIONS", "--target", mount_point) if source_on_disk else ""
c3 = criterion("mount_option_active", option in active_options.split(","), 2, f"active mount uses the {option} option", active_options or "not mounted")
persistent = False
evidence = "no matching entry"
part_node = parts[0]["node"] if parts else ""
device = active_source if source_on_disk else part_node
if device and os.path.exists("/etc/fstab"):
    device_real = os.path.realpath(device)
    uuid = run("blkid", "-s", "UUID", "-o", "value", device)
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 4 or fields[0].startswith("#") or fields[1] != mount_point or fields[2] != fs:
            continue
        source = fields[0]
        source_matches = (uuid and source == f"UUID={uuid}") or (not source.startswith(("UUID=", "LABEL=")) and os.path.realpath(source) == device_real)
        if source_matches and option in fields[3].split(","):
            persistent = True
            evidence = line.strip()
            break
c4 = criterion("persistent_fstab", persistent, 3, f"fstab restores the mount with the {option} option", evidence)
criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
