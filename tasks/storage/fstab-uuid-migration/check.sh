#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/fstab-uuid-migration","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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
part = f"{disk}1"
uuid = run("blkid", "-s", "UUID", "-o", "value", part)
entries = []
if os.path.exists("/etc/fstab"):
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) >= 3 and not fields[0].startswith("#") and fields[1] == mount_point:
            entries.append((fields, line.strip()))
uuid_entries = [item for item in entries if item[0][0].startswith("UUID=")]
c1 = criterion("fstab_uuid_entry", any(item[0][2] == fs for item in uuid_entries), 3, "fstab identifies the mount by UUID", uuid_entries[0][1] if uuid_entries else "no UUID= entry for the mount point")
uuid_correct = bool(uuid) and any(item[0][0] == f"UUID={uuid}" and item[0][2] == fs for item in uuid_entries)
c2 = criterion("uuid_matches", uuid_correct, 3, "fstab UUID matches the filesystem on the partition", f"expected UUID={uuid or 'unavailable'}")
stale = [item[1] for item in entries if not item[0][0].startswith(("UUID=", "LABEL="))]
c3 = criterion("no_device_path_entry", bool(entries) and not stale, 2, "no device-path entry remains for the mount point", stale[0] if stale else (entries[0][1] if entries else "no entry at all"))
active_source = run("findmnt", "-no", "SOURCE", "--target", mount_point)
active_fs = run("findmnt", "-no", "FSTYPE", "--target", mount_point)
mounted = bool(active_source) and os.path.realpath(active_source) == os.path.realpath(part) and active_fs == fs
c4 = criterion("mounted_filesystem", mounted, 2, "partition is still mounted at the requested mount point", f"{active_source or 'not mounted'} ({active_fs or '-'})")
criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
