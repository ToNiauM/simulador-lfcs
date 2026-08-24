#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/static-route-persistent","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

nic = p["lab_nic"]
address = p["lab_ip"]
prefix = int(p["prefix_len"])
gateway = p["gateway"]
dest = p["dest_network"]

addr_active = False
addr_evidence = "address not active"
try:
    for entry in json.loads(run("ip", "-j", "addr", "show", "dev", nic) or "[]"):
        for info in entry.get("addr_info", []):
            if info.get("local") == address and int(info.get("prefixlen", -1)) == prefix:
                addr_active = True
                addr_evidence = f"{info['local']}/{info['prefixlen']} on {nic}"
except ValueError:
    addr_evidence = "ip -j addr unavailable"
c1 = criterion("lab_address_active", addr_active, 2, "lab interface keeps its static address", addr_evidence)

route_entry = None
route_evidence = f"no route to {dest}"
try:
    for route in json.loads(run("ip", "-j", "route", "show", dest) or "[]"):
        if route.get("dst") == dest:
            route_entry = route
            route_evidence = json.dumps(route)[:200]
            break
except ValueError:
    route_evidence = "ip -j route unavailable"
route_ok = bool(route_entry) and route_entry.get("gateway") == gateway
c2 = criterion("route_active", route_ok, 3, "route to the destination network via the requested gateway is active", route_evidence)

dev_ok = bool(route_entry) and route_entry.get("dev") == nic
c3 = criterion("route_device", dev_ok, 2, "active route uses the lab interface", (route_entry or {}).get("dev", "route missing"))

merged = run("netplan", "get", f"ethernets.{nic}.routes")
merged_flat = " ".join(merged.split())
merged_ok = dest in merged_flat and gateway in merged_flat
c4 = criterion("netplan_route", merged_ok, 3, "netplan persistently declares the route for the lab interface", merged_flat or "no routes in netplan for interface")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
