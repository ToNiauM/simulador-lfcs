#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/dns-resolver-custom","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import configparser, glob, json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run2(*args):
    try:
        proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError:
        return 1, ""
    return proc.returncode, proc.stdout.strip()
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

def kf_semis(cp, section, key):
    raw = cp.get(section, key, fallback="")
    return [item.strip() for item in raw.replace(";", " ").split() if item.strip()]

nic = p["lab_nic"]
dns1 = p["dns_server_1"]
dns2 = p["dns_server_2"]
domain = p["search_domain"]
dns_wanted = {dns1, dns2}

# Persistent configuration, any family mechanism; evidence names the mechanism.
ns_sources, search_sources = [], []
for path, entry in netplan_entries(nic):
    nameservers = entry.get("nameservers") or {}
    addresses = {str(item) for item in nameservers.get("addresses") or []}
    if dns_wanted <= addresses:
        ns_sources.append(f"netplan:{path}")
    if domain in [str(item) for item in nameservers.get("search") or []]:
        search_sources.append(f"netplan:{path}")
for path, seclist in networkd_entries(nic):
    dns_vals = {token for value in sd_values(seclist, "network", "dns") for token in value.split()}
    if dns_wanted <= dns_vals:
        ns_sources.append(f"networkd:{path}")
    domains = {token for value in sd_values(seclist, "network", "domains") for token in value.split()}
    if domain in domains:
        search_sources.append(f"networkd:{path}")
for path, cp in keyfile_entries(nic):
    dns_vals = set(kf_semis(cp, "ipv4", "dns")) | set(kf_semis(cp, "ipv6", "dns"))
    if dns_wanted <= dns_vals:
        ns_sources.append(f"keyfile:{path}")
    searches = set(kf_semis(cp, "ipv4", "dns-search")) | set(kf_semis(cp, "ipv6", "dns-search"))
    if domain in searches:
        search_sources.append(f"keyfile:{path}")

c1 = criterion("netplan_nameservers", bool(ns_sources), 3,
               "a persistent configuration (netplan, systemd-networkd or NetworkManager keyfile) declares both nameservers for the lab interface",
               ",".join(ns_sources) or "no persistent mechanism declares both nameservers")
c2 = criterion("netplan_search", bool(search_sources), 2,
               "a persistent configuration declares the search domain for the lab interface",
               ",".join(search_sources) or "no persistent mechanism declares the search domain")

# Active state: resolvectl when available, otherwise NetworkManager runtime,
# otherwise fall back to the verified persistent configuration.
rc, out = run2("resolvectl", "dns", nic)
if rc == 0:
    tokens = out.replace(":", " ").split()
    c3 = criterion("resolver_active", dns_wanted <= set(tokens), 3,
                   "both nameservers are active for the lab interface",
                   out or "resolvectl reports no DNS for interface")
else:
    rc_nm, out_nm = run2("nmcli", "-g", "IP4.DNS", "device", "show", nic)
    if rc_nm == 0:
        tokens = out_nm.replace("|", " ").split()
        c3 = criterion("resolver_active", dns_wanted <= set(tokens), 3,
                       "both nameservers are active for the lab interface (NetworkManager)",
                       ("nmcli IP4.DNS: " + " ".join(tokens)) if tokens else "nmcli reports no DNS for interface")
    else:
        c3 = criterion("resolver_active", bool(ns_sources), 3,
                       "resolvectl unavailable; accepted persistent nameserver configuration as active state",
                       ",".join(ns_sources) or "no state source available")

rc, out = run2("resolvectl", "domain", nic)
if rc == 0:
    tokens = out.replace(":", " ").split()
    c4 = criterion("search_active", domain in tokens, 2,
                   "search domain is active for the lab interface",
                   out or "resolvectl reports no search domain")
else:
    rc_nm, out_nm = run2("nmcli", "-g", "IP4.DOMAIN", "device", "show", nic)
    if rc_nm == 0:
        tokens = out_nm.replace("|", " ").split()
        c4 = criterion("search_active", domain in tokens, 2,
                       "search domain is active for the lab interface (NetworkManager)",
                       ("nmcli IP4.DOMAIN: " + " ".join(tokens)) if tokens else "nmcli reports no search domain")
    else:
        c4 = criterion("search_active", bool(search_sources), 2,
                       "resolvectl unavailable; accepted persistent search-domain configuration as active state",
                       ",".join(search_sources) or "no state source available")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
