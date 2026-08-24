#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/service-resource-limits","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, re, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

unit = p["service_name"] + ".service"
expected_bytes = int(p["memory_max_mib"]) * 1024 * 1024
expected_cpu_usec = int(p["cpu_quota_pct"]) * 10000
expected_tasks = str(p["tasks_max"])

state = run("systemctl", "is-active", unit)
c1 = criterion("service_active", state == "active", 2, "service is running", f"systemctl is-active: {state or 'unknown'}")

memory_max = run("systemctl", "show", unit, "-p", "MemoryMax", "--value")
c2 = criterion("memory_max", memory_max == str(expected_bytes), 2, "MemoryMax matches the requested limit", f"MemoryMax={memory_max or 'unset'} (expected {expected_bytes})")

def timespan_to_usec(text):
    total = 0.0
    for value, sign_unit in re.findall(r"([0-9.]+)\s*(us|ms|s|min|h)", text):
        factor = {"us": 1, "ms": 1000, "s": 1000000, "min": 60000000, "h": 3600000000}[sign_unit]
        total += float(value) * factor
    return int(total)

cpu_quota = run("systemctl", "show", unit, "-p", "CPUQuotaPerSecUSec", "--value")
cpu_ok = bool(cpu_quota) and cpu_quota != "infinity" and timespan_to_usec(cpu_quota) == expected_cpu_usec
c3 = criterion("cpu_quota", cpu_ok, 2, "CPUQuota matches the requested percentage", f"CPUQuotaPerSecUSec={cpu_quota or 'unset'} (expected {expected_cpu_usec}us)")

tasks_max = run("systemctl", "show", unit, "-p", "TasksMax", "--value")
c4 = criterion("tasks_max", tasks_max == expected_tasks, 2, "TasksMax matches the requested limit", f"TasksMax={tasks_max or 'unset'} (expected {expected_tasks})")

def value_to_bytes(text):
    text = text.strip()
    match = re.fullmatch(r"([0-9.]+)\s*([KMGT]?)i?B?", text)
    if not match:
        return -1
    factor = {"": 1, "K": 1024, "M": 1024**2, "G": 1024**3, "T": 1024**4}[match.group(2)]
    return int(float(match.group(1)) * factor)

persistent_evidence = "no persistent MemoryMax configuration found under /etc/systemd"
persistent = False
candidates = [f"/etc/systemd/system/{unit}"]
candidates += sorted(glob.glob(f"/etc/systemd/system/{unit}.d/*.conf"))
candidates += sorted(glob.glob(f"/etc/systemd/system.control/{unit}.d/*.conf"))
for path in candidates:
    try:
        lines = open(path).read().splitlines()
    except OSError:
        continue
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(("#", ";")) or "=" not in stripped:
            continue
        key, _, value = stripped.partition("=")
        if key.strip() == "MemoryMax" and value_to_bytes(value) == expected_bytes:
            persistent = True
            persistent_evidence = f"{path}: {stripped}"
c5 = criterion("limits_persistent", persistent, 2, "resource limits are configured persistently on disk", persistent_evidence)

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
