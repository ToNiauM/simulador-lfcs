#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/bridge-with-dummy","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import configparser, glob, ipaddress, json, os, re, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.stdout
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}
def jlink(name):
    try:
        data = json.loads(run("ip", "-d", "-j", "link", "show", "dev", name) or "[]")
    except json.JSONDecodeError:
        data = []
    return data[0] if data else {}

bridge = p["bridge_name"]
dummy = p["dummy_if"]
expected_ip = ipaddress.ip_interface(p["bridge_ip"])

br = jlink(bridge)
br_kind = br.get("linkinfo", {}).get("info_kind")
br_up = "UP" in br.get("flags", [])
c1 = criterion("bridge_exists", br_kind == "bridge" and br_up, 2,
               "bridge interface exists and is up",
               f"kind:{br_kind or 'absent'} flags:{','.join(br.get('flags', []))}")

dm = jlink(dummy)
dm_kind = dm.get("linkinfo", {}).get("info_kind")
dm_master = dm.get("master")
c2 = criterion("dummy_enslaved", dm_kind == "dummy" and dm_master == bridge, 2,
               "dummy interface exists and is a port of the bridge",
               f"kind:{dm_kind or 'absent'} master:{dm_master or 'none'}")

active_ip = ""
try:
    addrs = json.loads(run("ip", "-j", "addr", "show", "dev", bridge) or "[]")
except json.JSONDecodeError:
    addrs = []
for entry in addrs:
    for info in entry.get("addr_info", []):
        if info.get("family") != "inet":
            continue
        try:
            if ipaddress.ip_interface(f"{info['local']}/{info['prefixlen']}") == expected_ip:
                active_ip = f"{info['local']}/{info['prefixlen']}"
        except (KeyError, ValueError):
            continue
c3 = criterion("bridge_ip", bool(active_ip), 2,
               "requested address is active on the bridge",
               active_ip or "address not present on bridge")

persist = ""
try:
    import yaml
    for path in sorted(glob.glob("/etc/netplan/*.yaml")):
        try:
            node = yaml.safe_load(open(path)) or {}
        except Exception:
            continue
        net = node.get("network", {}) or {}
        bridges = net.get("bridges", {}) or {}
        dummies = net.get("dummy-devices", {}) or {}
        cfg = bridges.get(bridge) or {}
        if dummy in (cfg.get("interfaces") or []) and dummy in dummies:
            persist = f"netplan:{path}"
except ImportError:
    pass
if not persist:
    netdev_kinds = {}
    bridged = False
    for path in sorted(glob.glob("/etc/systemd/network/*.netdev")):
        parser = configparser.ConfigParser(strict=False)
        try:
            parser.read(path)
        except Exception:
            continue
        if parser.has_section("NetDev"):
            netdev_kinds[parser.get("NetDev", "Name", fallback="")] = parser.get("NetDev", "Kind", fallback="")
    for path in sorted(glob.glob("/etc/systemd/network/*.network")):
        parser = configparser.ConfigParser(strict=False)
        try:
            parser.read(path)
        except Exception:
            continue
        if parser.get("Match", "Name", fallback="") == dummy and parser.get("Network", "Bridge", fallback="") == bridge:
            bridged = True
    if netdev_kinds.get(bridge) == "bridge" and netdev_kinds.get(dummy) == "dummy" and bridged:
        persist = "systemd-networkd:/etc/systemd/network"
if not persist:
    # NetworkManager keyfiles (RHEL family): a bridge profile for the bridge
    # plus a dummy profile enslaved to it.
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
    bridge_refs = {bridge}
    nm_bridge = ""
    for path, parser in conns:
        if parser.get("connection", "type", fallback="") == "bridge" and \
           parser.get("connection", "interface-name", fallback="") == bridge:
            nm_bridge = path
            bridge_refs.add(parser.get("connection", "uuid", fallback=""))
            bridge_refs.add(parser.get("connection", "id", fallback=""))
    bridge_refs.discard("")
    nm_dummy = ""
    for path, parser in conns:
        if parser.get("connection", "type", fallback="") != "dummy":
            continue
        if parser.get("connection", "interface-name", fallback="") != dummy:
            continue
        master = parser.get("connection", "master", fallback="") or \
                 parser.get("connection", "controller", fallback="")
        slave_type = parser.get("connection", "slave-type", fallback="") or \
                     parser.get("connection", "port-type", fallback="")
        if master in bridge_refs and slave_type in ("", "bridge"):
            nm_dummy = path
    if nm_bridge and nm_dummy:
        persist = f"nm-keyfile:{nm_bridge}"
c4 = criterion("persistent", bool(persist), 2,
               "bridge and dummy port are declared in persistent network configuration",
               persist or "no netplan, systemd-networkd or NetworkManager declaration found")

module_file = ""
for path in sorted(glob.glob("/etc/modules-load.d/*.conf")):
    try:
        text = open(path).read()
    except OSError:
        continue
    if re.search(r"(?m)^\s*dummy\s*$", text):
        module_file = path
        break
c5 = criterion("module_at_boot", bool(module_file), 2,
               "dummy kernel module is loaded at boot via modules-load.d",
               module_file or "no modules-load.d file lists dummy")

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
