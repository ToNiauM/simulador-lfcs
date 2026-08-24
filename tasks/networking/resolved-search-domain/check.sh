#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/resolved-search-domain","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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
wanted = {p["search_domain_1"], p["search_domain_2"]}

# Persistent config, any family mechanism; evidence names the mechanism.
found_domains, sources = set(), []

# netplan YAML (Debian family): interface stanza merged across all files.
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
        for section_name in ("ethernets", "vlans", "bridges", "bonds", "dummy-devices"):
            section = network.get(section_name) or {}
            entry = section.get(iface) if isinstance(section, dict) else None
            if not isinstance(entry, dict):
                continue
            search = ((entry.get("nameservers") or {}).get("search")) or []
            if isinstance(search, list) and search:
                found_domains.update(str(item) for item in search)
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
    domains = {token for name, kv in seclist if name == "network"
               for k, v in kv if k == "domains" for token in v.split()}
    if domains:
        found_domains.update(domains)
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
    if cp.get("connection", "interface-name", fallback="") != iface:
        continue
    searches = set()
    for section in ("ipv4", "ipv6"):
        raw = cp.get(section, "dns-search", fallback="")
        searches.update(item.strip() for item in raw.replace(";", " ").split() if item.strip())
    if searches:
        found_domains.update(searches)
        sources.append(f"keyfile:{path}")

c1 = criterion("netplan_search_domains", wanted <= found_domains, 4,
               "a persistent configuration (netplan, systemd-networkd or NetworkManager keyfile) declares both search domains on the interface",
               f"{','.join(sources) or 'no persistent stanza'}: search={sorted(found_domains) or '-'}")

# Active state: resolvectl when it responds, otherwise NetworkManager runtime,
# otherwise fall back to the verified persistent configuration.
rc, domain_out = run2("resolvectl", "domain", iface)
if rc == 0:
    active = set(domain_out.split(":", 1)[1].split()) if ":" in domain_out else set()
    c2 = criterion("resolved_link_domains", wanted <= active, 4,
                   "systemd-resolved reports both search domains on the link",
                   domain_out or "resolvectl returned nothing")
else:
    tokens = set()
    nm_ok = False
    for field in ("IP4.DOMAIN", "IP6.DOMAIN"):
        rc_nm, out_nm = run2("nmcli", "-g", field, "device", "show", iface)
        if rc_nm == 0:
            nm_ok = True
            tokens.update(out_nm.replace("|", " ").split())
    if nm_ok:
        c2 = criterion("resolved_link_domains", wanted <= tokens, 4,
                       "NetworkManager reports both search domains on the link",
                       ("nmcli domains: " + " ".join(sorted(tokens))) if tokens else "nmcli reports no search domains")
    else:
        c2 = criterion("resolved_link_domains", wanted <= found_domains, 4,
                       "resolvectl unavailable; accepted persistent search-domain configuration as active state",
                       ",".join(sources) or "no state source available")

resolved_state = run("systemctl", "is-active", "systemd-resolved.service")
nm_state = run("systemctl", "is-active", "NetworkManager.service")
dns_ok = resolved_state == "active" or nm_state == "active"
c3 = criterion("resolved_active", dns_ok,
               2, "a DNS-managing service is active (systemd-resolved or NetworkManager)",
               f"systemd-resolved={resolved_state or 'unknown'} NetworkManager={nm_state or 'unknown'}")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
