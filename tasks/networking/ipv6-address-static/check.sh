#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/ipv6-address-static","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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

# Persistence accepted from any family mechanism; evidence names the mechanism.
def matches(value):
    try:
        return ipaddress.ip_interface(str(value).split(",")[0].strip().strip('"')) == expected
    except ValueError:
        return False

sources = []

# netplan YAML (Debian family).
try:
    import yaml
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
            entry = sec.get(nic) if isinstance(sec, dict) else None
            if not isinstance(entry, dict):
                continue
            for item in entry.get("addresses") or []:
                values = list(item.keys()) if isinstance(item, dict) else [item]
                if any(matches(value) for value in values):
                    sources.append(f"netplan:{path}")
except ImportError:
    pass

# systemd-networkd units (Debian family alternative).
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
    if not any(nic in value.split() for value in names):
        continue
    values = [v for name, kv in seclist if name in ("network", "address") for k, v in kv if k == "address"]
    if any(matches(value) for value in values):
        sources.append(f"networkd:{path}")

# NetworkManager keyfiles (RHEL family).
for path in sorted(glob.glob("/etc/NetworkManager/system-connections/*")):
    if not os.path.isfile(path):
        continue
    cp = configparser.RawConfigParser(strict=False, delimiters=("=",))
    cp.optionxform = str
    try:
        cp.read_string(open(path).read())
    except Exception:
        continue
    if cp.get("connection", "interface-name", fallback="") != nic:
        continue
    if cp.has_section("ipv6"):
        for key, value in cp.items("ipv6"):
            if (key == "address" or (key.startswith("address") and key[len("address"):].isdigit())) and matches(value):
                sources.append(f"keyfile:{path}")

c3 = criterion("netplan_persistent", bool(sources), 4,
               "a persistent configuration (netplan, systemd-networkd or NetworkManager keyfile) declares the address on the interface",
               ",".join(sources) or "no persistent mechanism declares the address")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
