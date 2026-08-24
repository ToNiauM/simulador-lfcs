#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/second-nic-static-dns-full","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, subprocess, sys

import yaml

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
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

# Active DNS and search domain as seen by systemd-resolved.
dns_out = run("resolvectl", "dns", iface)
dns_active = set(dns_out.split(":", 1)[1].split()) if ":" in dns_out else set()
c3 = criterion("dns_active", dns_wanted <= dns_active, 2,
               "both DNS servers are active on the link", dns_out or "resolvectl returned nothing")
domain_out = run("resolvectl", "domain", iface)
domains_active = set(domain_out.split(":", 1)[1].split()) if ":" in domain_out else set()
c4 = criterion("search_domain_active", domain in domains_active, 1,
               "search domain is active on the link", domain_out or "resolvectl returned nothing")

# Persistent netplan configuration (merged view across files).
found = {"address": False, "route": False, "dns": set(), "search": False}
sources = []
for path in sorted(glob.glob("/etc/netplan/*.yaml")) + sorted(glob.glob("/etc/netplan/*.yml")):
    try:
        data = yaml.safe_load(open(path)) or {}
    except Exception:
        continue
    entry = ((data.get("network") or {}).get("ethernets") or {}).get(iface)
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
        sources.append(path)
persist_ok = found["address"] and found["route"] and dns_wanted <= found["dns"] and found["search"]
c5 = criterion("netplan_persistent", persist_ok, 3,
               "netplan restores address, route, DNS servers and search domain at boot",
               f"{','.join(sorted(set(sources))) or 'no netplan stanza'}: address={found['address']} route={found['route']} dns={sorted(found['dns']) or '-'} search={found['search']}")

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
