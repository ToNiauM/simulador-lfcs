#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/dns-resolver-custom","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

nic = p["lab_nic"]
dns1 = p["dns_server_1"]
dns2 = p["dns_server_2"]
domain = p["search_domain"]

merged_ns = run("netplan", "get", f"ethernets.{nic}.nameservers.addresses")
c1 = criterion("netplan_nameservers", dns1 in merged_ns and dns2 in merged_ns, 3, "netplan persistently declares both nameservers for the lab interface", " ".join(merged_ns.split()) or "no nameservers in netplan")

merged_search = run("netplan", "get", f"ethernets.{nic}.nameservers.search")
c2 = criterion("netplan_search", domain in merged_search, 2, "netplan persistently declares the search domain for the lab interface", " ".join(merged_search.split()) or "no search domain in netplan")

active_dns = run("resolvectl", "dns", nic)
tokens = active_dns.replace(":", " ").split()
c3 = criterion("resolver_active", dns1 in tokens and dns2 in tokens, 3, "both nameservers are active for the lab interface", active_dns or "resolvectl reports no DNS for interface")

active_domain = run("resolvectl", "domain", nic)
c4 = criterion("search_active", domain in active_domain.replace(":", " ").split(), 2, "search domain is active for the lab interface", active_domain or "resolvectl reports no search domain")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
