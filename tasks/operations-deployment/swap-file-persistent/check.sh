#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/swap-file-persistent","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

swap_file = p["swap_file"]
expected_mib = int(p["swap_size_mib"])
expected_swappiness = str(p["swappiness"])

size_mib = os.path.getsize(swap_file) / (1024 * 1024) if os.path.isfile(swap_file) else 0
size_ok = expected_mib <= size_mib < expected_mib + 5
c1 = criterion("swap_file_size", size_ok, 2, "swap file exists with the requested size", f"{swap_file}: {size_mib:.1f} MiB" if size_mib else "swap file missing")

active = False
active_evidence = "no matching entry in /proc/swaps"
try:
    for line in open("/proc/swaps"):
        fields = line.split()
        if len(fields) >= 2 and os.path.realpath(fields[0]) == os.path.realpath(swap_file) and fields[1] == "file":
            active = True
            active_evidence = line.strip()
            break
except OSError:
    pass
c2 = criterion("swap_active", active, 2, "swap file is currently active", active_evidence)

persistent = False
fstab_evidence = "no matching entry in /etc/fstab"
if os.path.exists("/etc/fstab"):
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 4 or fields[0].startswith("#"):
            continue
        if os.path.realpath(fields[0]) == os.path.realpath(swap_file) and fields[2] == "swap" and fields[1] in ("none", "swap"):
            persistent = True
            fstab_evidence = line.strip()
            break
c3 = criterion("swap_persistent", persistent, 2, "fstab activates the swap file at boot", fstab_evidence)

try:
    running = open("/proc/sys/vm/swappiness").read().strip()
except OSError:
    running = ""
c4 = criterion("swappiness_active", running == expected_swappiness, 2, "vm.swappiness has the requested runtime value", f"vm.swappiness = {running or 'unreadable'}")

conf_ok = False
conf_evidence = "no persistent vm.swappiness setting found"
conf_files = []
for directory in ("/etc/sysctl.d", "/usr/lib/sysctl.d", "/run/sysctl.d"):
    if os.path.isdir(directory):
        conf_files.extend(os.path.join(directory, name) for name in sorted(os.listdir(directory)) if name.endswith(".conf"))
if os.path.exists("/etc/sysctl.conf"):
    conf_files.append("/etc/sysctl.conf")
for path in conf_files:
    try:
        lines = open(path).read().splitlines()
    except OSError:
        continue
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(("#", ";")) or "=" not in stripped:
            continue
        key, _, value = stripped.partition("=")
        if key.strip() == "vm.swappiness":
            conf_ok = value.strip() == expected_swappiness
            conf_evidence = f"{path}: {stripped}"
c5 = criterion("swappiness_persistent", conf_ok, 2, "vm.swappiness is configured persistently via sysctl", conf_evidence)

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
