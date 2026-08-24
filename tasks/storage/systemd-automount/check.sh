#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/systemd-automount","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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

def resolve_source(source):
    if source.startswith("UUID="):
        return os.path.realpath(run("blkid", "-U", source[5:]) or "/nonexistent")
    if source.startswith("LABEL="):
        return os.path.realpath(run("blkid", "-L", source[6:]) or "/nonexistent")
    if source.startswith("PARTUUID=") or source.startswith("PARTLABEL="):
        return os.path.realpath(run("blkid", "-o", "device", "-t", source) or "/nonexistent")
    return os.path.realpath(source)

unit = run("systemd-escape", "-p", "--suffix=automount", mount_point)
active = run("systemctl", "is-active", unit)
c1 = criterion("automount_active", active == "active", 3, "systemd automount unit is active", f"{unit}: {active or 'unknown'}")

enabled = run("systemctl", "is-enabled", unit)
c2 = criterion("automount_persistent", enabled in ("enabled", "generated"), 2, "automount unit is restored at boot", f"{unit}: {enabled or 'unknown'}")

configured = False
evidence = "no matching fstab entry or unit file"
if os.path.exists("/etc/fstab"):
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 4 or fields[0].startswith("#") or fields[1] != mount_point or fields[2] != fs:
            continue
        if "x-systemd.automount" in fields[3].split(",") and resolve_source(fields[0]).startswith(disk):
            configured = True
            evidence = line.strip()
            break
if not configured:
    mount_unit = "/etc/systemd/system/" + run("systemd-escape", "-p", "--suffix=mount", mount_point)
    automount_unit = "/etc/systemd/system/" + run("systemd-escape", "-p", "--suffix=automount", mount_point)
    if os.path.isfile(mount_unit) and os.path.isfile(automount_unit):
        text = open(mount_unit).read()
        what = ""
        for entry in text.splitlines():
            if entry.strip().startswith("What="):
                what = entry.split("=", 1)[1].strip()
        if what and resolve_source(what).startswith(disk):
            configured = True
            evidence = f"unit files: {mount_unit}, What={what}"
c3 = criterion("automount_configured", configured, 2, "fstab entry or unit files define the automount", evidence)

triggered = False
evidence = "access did not trigger the mount"
try:
    os.listdir(mount_point)
except OSError:
    pass
mounted_fs = run("findmnt", "-no", "FSTYPE", mount_point)
mounted_src = run("findmnt", "-no", "SOURCE", mount_point)
sources = [s for s in mounted_src.splitlines() if not s.startswith("systemd-1")]
if mounted_fs and fs in mounted_fs.split():
    for source in sources:
        if os.path.realpath(source).startswith(disk):
            triggered = True
            evidence = f"{source} ({fs}) mounted on access"
            break
c4 = criterion("access_triggers_mount", triggered, 3, "accessing the directory mounts the filesystem", evidence if triggered else f"{mounted_src or 'nothing mounted'} ({mounted_fs or '-'})")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
