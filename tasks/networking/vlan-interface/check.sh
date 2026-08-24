#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/vlan-interface","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import configparser, glob, ipaddress, json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.stdout
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

nic = p["nic"]
vlan_id = int(p["vlan_id"])
vlan_iface = p["vlan_iface"]
expected_ip = ipaddress.ip_interface(p["vlan_ip"])

try:
    links = json.loads(run("ip", "-d", "-j", "link", "show", "dev", vlan_iface) or "[]")
except json.JSONDecodeError:
    links = []
link = links[0] if links else {}
up = "UP" in link.get("flags", [])
c1 = criterion("vlan_present", bool(link) and up, 2,
               "VLAN interface exists and is up",
               ",".join(link.get("flags", [])) if link else "interface not found")

info = link.get("linkinfo", {})
kind_ok = info.get("info_kind") == "vlan"
id_ok = info.get("info_data", {}).get("id") == vlan_id
parent_ok = link.get("link") == nic
c2 = criterion("vlan_id_link", kind_ok and id_ok and parent_ok, 3,
               "interface is a VLAN with the requested ID on the requested parent NIC",
               f"kind:{info.get('info_kind') or 'absent'} id:{info.get('info_data', {}).get('id')} parent:{link.get('link') or 'none'}")

active_ip = ""
try:
    addrs = json.loads(run("ip", "-j", "addr", "show", "dev", vlan_iface) or "[]")
except json.JSONDecodeError:
    addrs = []
for entry in addrs:
    for item in entry.get("addr_info", []):
        if item.get("family") != "inet":
            continue
        try:
            if ipaddress.ip_interface(f"{item['local']}/{item['prefixlen']}") == expected_ip:
                active_ip = f"{item['local']}/{item['prefixlen']}"
        except (KeyError, ValueError):
            continue
c3 = criterion("address_active", bool(active_ip), 2,
               "requested address is active on the VLAN interface",
               active_ip or "address not present")

persist = ""
try:
    import yaml
    for path in sorted(glob.glob("/etc/netplan/*.yaml")):
        try:
            node = yaml.safe_load(open(path)) or {}
        except Exception:
            continue
        vlans = ((node.get("network", {}) or {}).get("vlans", {}) or {})
        cfg = vlans.get(vlan_iface) or {}
        if cfg.get("id") == vlan_id and cfg.get("link") == nic:
            persist = f"netplan:{path}"
except ImportError:
    pass
if not persist:
    # NetworkManager keyfiles (RHEL family): a vlan profile with the requested
    # ID whose parent is the NIC (by interface name or by connection uuid/id).
    conns = []
    for path in sorted(glob.glob("/etc/NetworkManager/system-connections/*")):
        if not os.path.isfile(path):
            continue
        parser = configparser.ConfigParser(strict=False, interpolation=None)
        try:
            parser.read(path)
        except Exception:
            continue
        if parser.has_section("connection"):
            conns.append((path, parser))
    nic_refs = {nic}
    for path, parser in conns:
        if parser.get("connection", "interface-name", fallback="") == nic:
            nic_refs.add(parser.get("connection", "uuid", fallback=""))
            nic_refs.add(parser.get("connection", "id", fallback=""))
    nic_refs.discard("")
    for path, parser in conns:
        if parser.get("connection", "type", fallback="") != "vlan":
            continue
        if parser.get("connection", "interface-name", fallback="") != vlan_iface:
            continue
        if not parser.has_section("vlan"):
            continue
        kf_id = parser.get("vlan", "id", fallback="")
        kf_parent = parser.get("vlan", "parent", fallback="")
        if kf_id.strip() == str(vlan_id) and kf_parent in nic_refs:
            persist = f"nm-keyfile:{path}"
c4 = criterion("netplan_persistent", bool(persist), 3,
               "a persistent network configuration file declares the VLAN with the requested ID and parent",
               persist or "no netplan or NetworkManager configuration declares the VLAN")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
