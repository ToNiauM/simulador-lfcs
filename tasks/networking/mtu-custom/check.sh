#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/mtu-custom","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.stdout
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

nic = p["nic"]
expected_mtu = int(p["mtu"])

try:
    links = json.loads(run("ip", "-j", "link", "show", "dev", nic) or "[]")
except json.JSONDecodeError:
    links = []
link = links[0] if links else {}
up = "UP" in link.get("flags", [])
c1 = criterion("link_up", bool(link) and up, 2, "interface exists and is up",
               ",".join(link.get("flags", [])) if link else "interface not found")

actual_mtu = link.get("mtu")
c2 = criterion("mtu_active", actual_mtu == expected_mtu, 4,
               "requested MTU is active on the interface",
               f"mtu:{actual_mtu if actual_mtu is not None else 'unknown'}")

persist = ""
try:
    import yaml
    for path in sorted(glob.glob("/etc/netplan/*.yaml")):
        try:
            node = yaml.safe_load(open(path)) or {}
        except Exception:
            continue
        ethernets = ((node.get("network", {}) or {}).get("ethernets", {}) or {})
        cfg = ethernets.get(nic) or {}
        if cfg.get("mtu") == expected_mtu:
            persist = path
except ImportError:
    pass
c3 = criterion("netplan_persistent", bool(persist), 4,
               "a netplan file sets the requested MTU on the interface",
               persist or "no netplan file sets the MTU")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
