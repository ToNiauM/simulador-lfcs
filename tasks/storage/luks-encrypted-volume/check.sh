#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/luks-encrypted-volume","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, stat, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

disk = p["target_disk"]
fs = p["filesystem"]
mapper = p["mapper_name"]
key_file = p["key_file"]
mount_point = p["mount_point"]
mapper_path = f"/dev/mapper/{mapper}"

def resolve_source(source):
    if source.startswith("UUID="):
        return os.path.realpath(run("blkid", "-U", source[5:]) or "/nonexistent")
    if source.startswith("LABEL="):
        return os.path.realpath(run("blkid", "-L", source[6:]) or "/nonexistent")
    if source.startswith("PARTUUID=") or source.startswith("PARTLABEL="):
        return os.path.realpath(run("blkid", "-o", "device", "-t", source) or "/nonexistent")
    return os.path.realpath(source)

crypttab_ok = False
evidence = "no matching crypttab entry"
if os.path.exists("/etc/crypttab"):
    for line in open("/etc/crypttab"):
        fields = line.split()
        if len(fields) < 3 or fields[0].startswith("#") or fields[0] != mapper:
            continue
        if resolve_source(fields[1]).startswith(disk) and os.path.realpath(fields[2]) == os.path.realpath(key_file):
            crypttab_ok = True
            evidence = line.strip()
            break
c1 = criterion("crypttab_entry", crypttab_ok, 2, "crypttab unlocks the volume with the key file at boot", evidence)

key_ok = False
evidence = "key file missing"
try:
    info = os.stat(key_file)
    if stat.S_ISREG(info.st_mode) and info.st_size > 0 and (info.st_mode & 0o077) == 0:
        key_ok = True
    evidence = f"size={info.st_size} mode={stat.S_IMODE(info.st_mode):04o}"
except OSError:
    pass
c2 = criterion("key_file", key_ok, 2, "key file exists and is readable by root only", evidence)

status = run("cryptsetup", "status", mapper)
device_line = ""
for entry in status.splitlines():
    if entry.strip().startswith("device:"):
        device_line = entry.split(":", 1)[1].strip()
mapping_ok = "is active" in status and os.path.realpath(device_line or "/nonexistent").startswith(disk)
c3 = criterion("mapping_active", mapping_ok, 2, "encrypted mapping is open and backed by the task disk", f"device={device_line or '-'}" if status else "mapping not active")

mounted_fs = run("findmnt", "-no", "FSTYPE", mount_point)
mounted_src = run("findmnt", "-no", "SOURCE", mount_point)
mounted_ok = mounted_fs == fs and bool(mounted_src) and os.path.realpath(mounted_src) == os.path.realpath(mapper_path)
c4 = criterion("mounted_filesystem", mounted_ok, 2, "decrypted filesystem is mounted at the requested mount point", f"{mounted_src or 'not mounted'} ({mounted_fs or '-'})")

persistent = False
evidence = "no matching fstab entry"
fs_uuid = run("blkid", "-s", "UUID", "-o", "value", mapper_path) if os.path.exists(mapper_path) else ""
if os.path.exists("/etc/fstab"):
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 3 or fields[0].startswith("#") or fields[1] != mount_point or fields[2] != fs:
            continue
        source = fields[0]
        matches = (fs_uuid and source == f"UUID={fs_uuid}") or (not source.startswith(("UUID=", "LABEL=", "PARTUUID=", "PARTLABEL=")) and os.path.exists(mapper_path) and os.path.realpath(source) == os.path.realpath(mapper_path))
        if matches:
            persistent = True
            evidence = line.strip()
            break
c5 = criterion("persistent_fstab", persistent, 2, "fstab mounts the decrypted volume at boot", evidence)

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
