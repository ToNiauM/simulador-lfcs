#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/swap-partition","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

disk = p["target_disk"]
expected_kib = int(p["swap_size_mib"]) * 1024
expected_priority = int(p["swap_priority"])
entry = None
try:
    for line in open("/proc/swaps").read().splitlines()[1:]:
        fields = line.split()
        if len(fields) >= 5 and os.path.realpath(fields[0]).startswith(disk):
            entry = fields
            break
except OSError:
    pass
c1 = criterion("swap_active", entry is not None and entry[1] == "partition", 3, "swap partition on the task disk is active", " ".join(entry) if entry else "no active swap on the task disk")
size_kib = int(entry[2]) if entry else 0
c2 = criterion("swap_size", entry is not None and abs(size_kib - expected_kib) <= 8192, 2, f"swap area is {expected_kib // 1024} MiB", f"{size_kib} KiB" if entry else "no active swap")
c3 = criterion("swap_priority", entry is not None and int(entry[4]) == expected_priority, 2, f"swap priority is {expected_priority}", entry[4] if entry else "no active swap")
device = entry[0] if entry else ""
if not device:
    try:
        table = json.loads(run("sfdisk", "-J", disk)).get("partitiontable", {})
        parts = sorted(table.get("partitions", []), key=lambda item: item.get("start", 0))
        device = parts[0]["node"] if parts else ""
    except (ValueError, TypeError):
        device = ""
persistent = False
evidence = "no matching entry"
if device and os.path.exists("/etc/fstab"):
    device_real = os.path.realpath(device)
    uuid = run("blkid", "-s", "UUID", "-o", "value", device)
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 4 or fields[0].startswith("#") or fields[2] != "swap":
            continue
        source = fields[0]
        source_matches = (uuid and source == f"UUID={uuid}") or (not source.startswith(("UUID=", "LABEL=")) and os.path.realpath(source) == device_real)
        if source_matches and f"pri={expected_priority}" in fields[3].split(","):
            persistent = True
            evidence = line.strip()
            break
c4 = criterion("persistent_fstab", persistent, 3, f"fstab restores the swap with priority {expected_priority}", evidence)
criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
