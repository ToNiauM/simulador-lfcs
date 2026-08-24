#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/resolved-search-domain","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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
wanted = {p["search_domain_1"], p["search_domain_2"]}

# Persistent config: interface stanza merged across all netplan files.
yaml_domains, yaml_sources = set(), []
paths = sorted(glob.glob("/etc/netplan/*.yaml")) + sorted(glob.glob("/etc/netplan/*.yml"))
for path in paths:
    try:
        data = yaml.safe_load(open(path)) or {}
    except Exception:
        continue
    network = data.get("network") or {}
    for section_name in ("ethernets", "vlans", "bridges", "bonds"):
        section = network.get(section_name) or {}
        entry = section.get(iface)
        if not isinstance(entry, dict):
            continue
        search = ((entry.get("nameservers") or {}).get("search")) or []
        if isinstance(search, list) and search:
            yaml_domains.update(str(item) for item in search)
            yaml_sources.append(path)
c1 = criterion("netplan_search_domains", wanted <= yaml_domains, 4,
               "netplan configures both search domains on the interface",
               f"{','.join(yaml_sources) or 'no netplan stanza'}: search={sorted(yaml_domains) or '-'}")

# Active state as seen by systemd-resolved.
domain_out = run("resolvectl", "domain", iface)
active = set(domain_out.split(":", 1)[1].split()) if ":" in domain_out else set()
c2 = criterion("resolved_link_domains", wanted <= active, 4,
               "systemd-resolved reports both search domains on the link",
               domain_out or "resolvectl returned nothing")

state = run("systemctl", "is-active", "systemd-resolved.service")
c3 = criterion("resolved_active", state == "active", 2,
               "systemd-resolved service is active", state or "unknown")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
