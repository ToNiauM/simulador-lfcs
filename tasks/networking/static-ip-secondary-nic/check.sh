#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/static-ip-secondary-nic","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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

def sd_values(seclist, section, key):
    return [v for name, kv in seclist for k, v in kv if name == section and k == key]

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
address = p["ip_address"]
prefix = int(p["prefix_len"])
cidr = f"{address}/{prefix}"

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

# Persistence accepted from any family mechanism; evidence names the mechanism.
mechs = []
for path, entry in netplan_entries(nic):
    found = False
    for item in entry.get("addresses") or []:
        values = list(item.keys()) if isinstance(item, dict) else [item]
        if any(str(value) == cidr for value in values):
            found = True
    if found:
        mechs.append((f"netplan:{path}", entry.get("dhcp4") not in (True, "true", "yes")))
for path, seclist in networkd_entries(nic):
    addrs = sd_values(seclist, "network", "address") + sd_values(seclist, "address", "address")
    if cidr in addrs:
        dhcp = [value.lower() for value in sd_values(seclist, "network", "dhcp")]
        mechs.append((f"networkd:{path}", all(value in ("no", "false", "0", "ipv6") for value in dhcp)))
for path, cp in keyfile_entries(nic):
    if any(value.split(",")[0].strip() == cidr for value in kf_list(cp, "ipv4", "address")):
        mechs.append((f"keyfile:{path}", cp.get("ipv4", "method", fallback="") == "manual"))

c3 = criterion("netplan_file", bool(mechs), 3,
               "a persistent configuration (netplan, systemd-networkd or NetworkManager keyfile) declares the address for the lab interface",
               ",".join(src for src, _ in mechs) or "no persistent mechanism declares the address")
dhcp_off = [src for src, ok in mechs if ok]
c4 = criterion("netplan_merged", bool(dhcp_off), 2,
               "persistent configuration keeps the address with DHCP disabled",
               ",".join(dhcp_off) or "no persistent mechanism declares the address with DHCP disabled")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
