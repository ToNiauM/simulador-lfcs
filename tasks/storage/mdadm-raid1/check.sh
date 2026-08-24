#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/mdadm-raid1","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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
disk_base = os.path.basename(disk)

raid_ok = False
evidence = "no active raid1 array on the task disk"
mdstat = ""
try:
    mdstat = open("/proc/mdstat").read()
except OSError:
    pass
for line in mdstat.splitlines():
    if " : active " not in line and " : active(" not in line:
        continue
    if "raid1" not in line:
        continue
    members = [tok.split("[")[0] for tok in line.split() if "[" in tok]
    vdb_members = [m for m in members if m.startswith(disk_base)]
    if len(vdb_members) >= 2:
        raid_ok = True
        evidence = line.strip()
        break
c1 = criterion("raid1_active", raid_ok, 3, "active RAID1 array uses two partitions of the task disk", evidence)

conf_ok = False
evidence = "no ARRAY line in mdadm.conf"
for conf in ("/etc/mdadm/mdadm.conf", "/etc/mdadm.conf"):
    if not os.path.exists(conf):
        continue
    for line in open(conf):
        stripped = line.strip()
        if stripped.startswith("ARRAY"):
            conf_ok = True
            evidence = f"{conf}: {stripped}"
            break
    if conf_ok:
        break
c2 = criterion("mdadm_conf", conf_ok, 2, "array is recorded in mdadm.conf", evidence)

mounted_fs = run("findmnt", "-no", "FSTYPE", mount_point)
mounted_src = run("findmnt", "-no", "SOURCE", mount_point)
src_real = os.path.realpath(mounted_src) if mounted_src else ""
mounted_ok = mounted_fs == fs and src_real.startswith("/dev/md")
c3 = criterion("mounted_filesystem", mounted_ok, 3, "filesystem on the RAID array is mounted at the requested mount point", f"{mounted_src or 'not mounted'} ({mounted_fs or '-'})")

persistent = False
evidence = "no matching fstab entry"
fs_uuid = run("blkid", "-s", "UUID", "-o", "value", src_real) if src_real else ""
if os.path.exists("/etc/fstab"):
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 3 or fields[0].startswith("#") or fields[1] != mount_point or fields[2] != fs:
            continue
        source = fields[0]
        matches = (fs_uuid and source == f"UUID={fs_uuid}") or (not source.startswith(("UUID=", "LABEL=", "PARTUUID=", "PARTLABEL=")) and os.path.realpath(source).startswith("/dev/md"))
        if matches:
            persistent = True
            evidence = line.strip()
            break
c4 = criterion("persistent_fstab", persistent, 2, "fstab restores the mount at boot", evidence)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
