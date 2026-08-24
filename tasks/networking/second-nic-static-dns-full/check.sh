#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/second-nic-static-dns-full","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import configparser, glob, json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def run2(*args):
    try:
        proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError:
        return 1, ""
    return proc.returncode, proc.stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

iface = p["interface"]
cidr = p["address"]
plain_ip, prefix_len = cidr.split("/")
prefix_len = int(prefix_len)
route_to = p["route_to"]
route_via = p["route_via"]
dns_wanted = {p["dns_1"], p["dns_2"]}
domain = p["search_domain"]

# Active address via ip -j.
try:
    links = json.loads(run("ip", "-j", "addr", "show", "dev", iface) or "[]")
except json.JSONDecodeError:
    links = []
addr_info = links[0].get("addr_info", []) if links else []
addr_ok = any(a.get("local") == plain_ip and a.get("prefixlen") == prefix_len for a in addr_info)
addr_summary = " ".join(f"{a.get('local')}/{a.get('prefixlen')}" for a in addr_info if a.get("family") == "inet")
c1 = criterion("address_active", addr_ok, 2,
               "static address is active on the interface", addr_summary or f"no IPv4 address on {iface}")

# Active route via ip -j.
try:
    routes = json.loads(run("ip", "-j", "route", "show", route_to) or "[]")
except json.JSONDecodeError:
    routes = []
route_ok = any(r.get("dst") == route_to and r.get("dev") == iface and r.get("gateway") == route_via for r in routes)
route_summary = " ".join(f"{r.get('dst')} via {r.get('gateway')} dev {r.get('dev')}" for r in routes)
c2 = criterion("route_active", route_ok, 2,
               "static route to the lab subnet goes through the required gateway", route_summary or "route missing")

# Persistent configuration, any family mechanism; evidence names the mechanism.
found = {"address": False, "route": False, "dns": set(), "search": False}
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
        ethernets = network.get("ethernets") if isinstance(network, dict) else None
        entry = ethernets.get(iface) if isinstance(ethernets, dict) else None
        if not isinstance(entry, dict):
            continue
        touched = False
        for value in entry.get("addresses") or []:
            if str(value) == cidr:
                found["address"] = True
                touched = True
        for route in entry.get("routes") or []:
            if isinstance(route, dict) and str(route.get("to")) == route_to and str(route.get("via")) == route_via:
                found["route"] = True
                touched = True
        nameservers = entry.get("nameservers") or {}
        for value in nameservers.get("addresses") or []:
            found["dns"].add(str(value))
            touched = True
        if domain in [str(item) for item in nameservers.get("search") or []]:
            found["search"] = True
            touched = True
        if touched:
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
    if not any(iface in value.split() for value in names):
        continue
    touched = False
    addrs = [v for name, kv in seclist if name in ("network", "address") for k, v in kv if k == "address"]
    if cidr in addrs:
        found["address"] = True
        touched = True
    for kv in (kv for name, kv in seclist if name == "route"):
        dests = [v for k, v in kv if k == "destination"]
        gws = [v for k, v in kv if k == "gateway"]
        if route_to in dests and route_via in gws:
            found["route"] = True
            touched = True
    dns_vals = {token for name, kv in seclist if name == "network" for k, v in kv if k == "dns" for token in v.split()}
    if dns_vals:
        found["dns"].update(dns_vals)
        touched = True
    domains = {token for name, kv in seclist if name == "network" for k, v in kv if k == "domains" for token in v.split()}
    if domain in domains:
        found["search"] = True
        touched = True
    if touched:
        sources.append(f"networkd:{path}")

# NetworkManager keyfiles (RHEL family).
def kf_list(cp, section, prefix):
    vals = []
    if cp.has_section(section):
        for key, value in cp.items(section):
            if key == prefix or (key.startswith(prefix) and key[len(prefix):].isdigit()):
                vals.append(value.strip())
    return vals

for path in sorted(glob.glob("/etc/NetworkManager/system-connections/*")):
    if not os.path.isfile(path):
        continue
    cp = configparser.RawConfigParser(strict=False, delimiters=("=",))
    cp.optionxform = str
    try:
        cp.read_string(open(path).read())
    except Exception:
        continue
    if cp.get("connection", "interface-name", fallback="") != iface:
        continue
    touched = False
    if any(value.split(",")[0].strip() == cidr for value in kf_list(cp, "ipv4", "address")):
        found["address"] = True
        touched = True
    for value in kf_list(cp, "ipv4", "route"):
        parts = [part.strip() for part in value.split(",")]
        if len(parts) >= 2 and parts[0] == route_to and parts[1] == route_via:
            found["route"] = True
            touched = True
    dns_vals = {item.strip() for item in cp.get("ipv4", "dns", fallback="").replace(";", " ").split() if item.strip()}
    if dns_vals:
        found["dns"].update(dns_vals)
        touched = True
    searches = {item.strip() for item in cp.get("ipv4", "dns-search", fallback="").replace(";", " ").split() if item.strip()}
    if domain in searches:
        found["search"] = True
        touched = True
    if touched:
        sources.append(f"keyfile:{path}")

persist_dns_ok = dns_wanted <= found["dns"]
persist_search_ok = found["search"]

# Active DNS and search domain: resolvectl when it responds, otherwise
# NetworkManager runtime, otherwise the verified persistent configuration.
rc, dns_out = run2("resolvectl", "dns", iface)
if rc == 0:
    dns_active = set(dns_out.split(":", 1)[1].split()) if ":" in dns_out else set()
    c3 = criterion("dns_active", dns_wanted <= dns_active, 2,
                   "both DNS servers are active on the link", dns_out or "resolvectl returned nothing")
else:
    rc_nm, out_nm = run2("nmcli", "-g", "IP4.DNS", "device", "show", iface)
    if rc_nm == 0:
        tokens = set(out_nm.replace("|", " ").split())
        c3 = criterion("dns_active", dns_wanted <= tokens, 2,
                       "both DNS servers are active on the link (NetworkManager)",
                       ("nmcli IP4.DNS: " + " ".join(sorted(tokens))) if tokens else "nmcli reports no DNS on link")
    else:
        c3 = criterion("dns_active", persist_dns_ok, 2,
                       "resolvectl unavailable; accepted persistent DNS configuration as active state",
                       ",".join(sources) or "no state source available")

rc, domain_out = run2("resolvectl", "domain", iface)
if rc == 0:
    domains_active = set(domain_out.split(":", 1)[1].split()) if ":" in domain_out else set()
    c4 = criterion("search_domain_active", domain in domains_active, 1,
                   "search domain is active on the link", domain_out or "resolvectl returned nothing")
else:
    rc_nm, out_nm = run2("nmcli", "-g", "IP4.DOMAIN", "device", "show", iface)
    if rc_nm == 0:
        tokens = set(out_nm.replace("|", " ").split())
        c4 = criterion("search_domain_active", domain in tokens, 1,
                       "search domain is active on the link (NetworkManager)",
                       ("nmcli IP4.DOMAIN: " + " ".join(sorted(tokens))) if tokens else "nmcli reports no search domain on link")
    else:
        c4 = criterion("search_domain_active", persist_search_ok, 1,
                       "resolvectl unavailable; accepted persistent search-domain configuration as active state",
                       ",".join(sources) or "no state source available")

persist_ok = found["address"] and found["route"] and persist_dns_ok and persist_search_ok
c5 = criterion("netplan_persistent", persist_ok, 3,
               "a persistent configuration (netplan, systemd-networkd or NetworkManager keyfile) restores address, route, DNS servers and search domain at boot",
               f"{','.join(sorted(set(sources))) or 'no persistent stanza'}: address={found['address']} route={found['route']} dns={sorted(found['dns']) or '-'} search={found['search']}")

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
