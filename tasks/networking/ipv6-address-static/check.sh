#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/ipv6-address-static","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, ipaddress, json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.stdout
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

nic = p["nic"]
expected = ipaddress.ip_interface(p["ipv6_address"])

try:
    links = json.loads(run("ip", "-j", "link", "show", "dev", nic) or "[]")
except json.JSONDecodeError:
    links = []
link_up = bool(links) and "UP" in links[0].get("flags", [])
c1 = criterion("link_up", link_up, 2, "interface exists and is up",
               ",".join(links[0].get("flags", [])) if links else "interface not found")

try:
    addrs = json.loads(run("ip", "-j", "addr", "show", "dev", nic) or "[]")
except json.JSONDecodeError:
    addrs = []
active = ""
for entry in addrs:
    for info in entry.get("addr_info", []):
        if info.get("family") != "inet6":
            continue
        try:
            candidate = ipaddress.ip_interface(f"{info['local']}/{info['prefixlen']}")
        except (KeyError, ValueError):
            continue
        if candidate == expected and info.get("scope") == "global":
            active = f"{info['local']}/{info['prefixlen']} scope {info['scope']}"
c2 = criterion("address_active", bool(active), 4,
               "requested IPv6 address is active on the interface with global scope",
               active or "address not present")

def yaml_addresses(node):
    found = []
    raw = ((node or {}).get("network", {}) or {}).get("ethernets", {}) or {}
    iface = raw.get(nic) or {}
    for item in iface.get("addresses") or []:
        if isinstance(item, dict):
            found.extend(item.keys())
        else:
            found.append(item)
    return found

persist_file = ""
try:
    import yaml
    for path in sorted(glob.glob("/etc/netplan/*.yaml")):
        try:
            node = yaml.safe_load(open(path))
        except Exception:
            continue
        for entry in yaml_addresses(node):
            try:
                if ipaddress.ip_interface(str(entry)) == expected:
                    persist_file = path
            except ValueError:
                continue
except ImportError:
    pass
c3 = criterion("netplan_persistent", bool(persist_file), 4,
               "a netplan file configures the address on the interface",
               persist_file or "no netplan file declares the address")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
