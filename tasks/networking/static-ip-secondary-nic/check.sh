#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/static-ip-secondary-nic","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

nic = p["lab_nic"]
address = p["ip_address"]
prefix = int(p["prefix_len"])
cidr = f"{address}/{prefix}"
netplan_file = p["netplan_file"]

link_json = run("ip", "-j", "link", "show", "dev", nic)
try:
    link_up = bool(json.loads(link_json))
except ValueError:
    link_up = False
c1 = criterion("nic_present", link_up, 2, "lab interface exists", link_json[:80] or f"{nic} missing")

addr_active = False
addr_evidence = "address not active"
addr_json = run("ip", "-j", "addr", "show", "dev", nic)
try:
    for entry in json.loads(addr_json or "[]"):
        for info in entry.get("addr_info", []):
            if info.get("local") == address and int(info.get("prefixlen", -1)) == prefix:
                addr_active = True
                addr_evidence = f"{info['local']}/{info['prefixlen']} on {nic}"
except ValueError:
    addr_evidence = "ip -j addr unavailable"
c2 = criterion("address_active", addr_active, 3, "requested static address is active on the lab interface", addr_evidence)

file_ok = False
file_evidence = f"{netplan_file} missing"
if os.path.isfile(netplan_file):
    text = open(netplan_file).read()
    file_evidence = " ".join(text.split())[:200]
    file_ok = nic in text and cidr in text
c3 = criterion("netplan_file", file_ok, 3, "requested netplan file declares the address for the lab interface", file_evidence)

merged = run("netplan", "get", f"ethernets.{nic}")
merged_ok = bool(merged) and cidr in merged and "dhcp4: true" not in merged
c4 = criterion("netplan_merged", merged_ok, 2, "merged netplan configuration keeps the address persistent with DHCP disabled", " ".join(merged.split()) or "no netplan config for interface")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
