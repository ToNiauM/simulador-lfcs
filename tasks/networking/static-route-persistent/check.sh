#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/static-route-persistent","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import configparser, glob, json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

# Persistent-config readers: netplan YAML, systemd-networkd units, NetworkManager keyfiles.
def netplan_entries(iface):
    try:
        import yaml
    except Exception:
        return []
    out = []
    for path in sorted(glob.glob("/etc/netplan/*.yaml")) + sorted(glob.glob("/etc/netplan/*.yml")):
        try:
            data = yaml.safe_load(open(path)) or {}
        except Exception:
            continue
        network = data.get("network") if isinstance(data, dict) else None
        if not isinstance(network, dict):
            continue
        for section in ("ethernets", "vlans", "bridges", "bonds", "dummy-devices"):
            sec = network.get(section)
            entry = sec.get(iface) if isinstance(sec, dict) else None
            if isinstance(entry, dict):
                out.append((path, entry))
    return out

def networkd_entries(iface):
    out = []
    for path in sorted(glob.glob("/etc/systemd/network/*.network")):
        seclist, kvs = [], None
        try:
            text = open(path).read()
        except OSError:
            continue
        for line in text.splitlines():
            line = line.strip()
            if not line or line[0] in "#;":
                continue
            if line.startswith("[") and line.endswith("]"):
                kvs = []
                seclist.append((line[1:-1].strip().lower(), kvs))
            elif "=" in line and kvs is not None:
                key, _, value = line.partition("=")
                kvs.append((key.strip().lower(), value.strip()))
        names = [v for name, kv in seclist if name == "match" for k, v in kv if k == "name"]
        if any(iface in value.split() for value in names):
            out.append((path, seclist))
    return out

def sd_sections(seclist, section):
    return [kv for name, kv in seclist if name == section]

def keyfile_entries(iface):
    out = []
    for path in sorted(glob.glob("/etc/NetworkManager/system-connections/*")):
        if not os.path.isfile(path):
            continue
        cp = configparser.RawConfigParser(strict=False, delimiters=("=",))
        cp.optionxform = str
        try:
            cp.read_string(open(path).read())
        except Exception:
            continue
        try:
            bound = cp.get("connection", "interface-name")
        except Exception:
            bound = ""
        if bound == iface:
            out.append((path, cp))
    return out

def kf_list(cp, section, prefix):
    vals = []
    if cp.has_section(section):
        for key, value in cp.items(section):
            if key == prefix or (key.startswith(prefix) and key[len(prefix):].isdigit()):
                vals.append(value.strip())
    return vals

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

# Persistence accepted from any family mechanism; evidence names the mechanism.
route_sources = []
for path, entry in netplan_entries(nic):
    for route in entry.get("routes") or []:
        if isinstance(route, dict) and str(route.get("to")) == dest and str(route.get("via")) == gateway:
            route_sources.append(f"netplan:{path}")
for path, seclist in networkd_entries(nic):
    for kv in sd_sections(seclist, "route"):
        dests = [v for k, v in kv if k == "destination"]
        gws = [v for k, v in kv if k == "gateway"]
        if dest in dests and gateway in gws:
            route_sources.append(f"networkd:{path}")
for path, cp in keyfile_entries(nic):
    for value in kf_list(cp, "ipv4", "route"):
        parts = [part.strip() for part in value.split(",")]
        if len(parts) >= 2 and parts[0] == dest and parts[1] == gateway:
            route_sources.append(f"keyfile:{path}")

c4 = criterion("netplan_route", bool(route_sources), 3,
               "a persistent configuration (netplan, systemd-networkd or NetworkManager keyfile) declares the route for the lab interface",
               ",".join(route_sources) or "no persistent mechanism declares the route")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
