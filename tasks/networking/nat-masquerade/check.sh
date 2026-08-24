#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/nat-masquerade","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, os, re, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

subnet = p["lan_subnet"]
wan = p["wan_interface"]
net_addr, net_len = subnet.split("/")
net_len = int(net_len)

# Active masquerade rule via nft JSON output.
try:
    ruleset = json.loads(run("nft", "-j", "list", "ruleset") or '{"nftables":[]}')
except json.JSONDecodeError:
    ruleset = {"nftables": []}
chains = {}
for item in ruleset.get("nftables", []):
    if isinstance(item, dict) and "chain" in item:
        chain = item["chain"]
        chains[(chain.get("family"), chain.get("table"), chain.get("name"))] = chain
active_evidence = "no matching rule in any nat/postrouting chain"
active_ok = False
for item in ruleset.get("nftables", []):
    rule = item.get("rule") if isinstance(item, dict) else None
    if not rule:
        continue
    chain = chains.get((rule.get("family"), rule.get("table"), rule.get("chain")), {})
    if chain.get("type") != "nat" or chain.get("hook") != "postrouting":
        continue
    saddr_ok = oif_ok = masq_ok = False
    for expr in rule.get("expr", []):
        if not isinstance(expr, dict):
            continue
        if "masquerade" in expr:
            masq_ok = True
        match = expr.get("match")
        if not isinstance(match, dict):
            continue
        left, right = match.get("left"), match.get("right")
        if isinstance(left, dict) and left.get("payload", {}).get("field") == "saddr":
            if isinstance(right, dict) and "prefix" in right:
                prefix = right["prefix"]
                if prefix.get("addr") == net_addr and int(prefix.get("len", -1)) == net_len:
                    saddr_ok = True
            elif right == net_addr and net_len == 32:
                saddr_ok = True
        if isinstance(left, dict) and left.get("meta", {}).get("key") == "oifname":
            names = right.get("set") if isinstance(right, dict) else right
            if not isinstance(names, list):
                names = [names]
            if wan in [str(name) for name in names]:
                oif_ok = True
    if saddr_ok and oif_ok and masq_ok:
        active_ok = True
        active_evidence = f"table {rule.get('table')} chain {rule.get('chain')}: ip saddr {subnet} oifname {wan} masquerade"
        break
c1 = criterion("masquerade_active", active_ok, 3, "active nftables masquerade rule matches subnet and egress interface", active_evidence)

forward_now = ""
try:
    forward_now = open("/proc/sys/net/ipv4/ip_forward").read().strip()
except OSError:
    pass
c2 = criterion("forwarding_active", forward_now == "1", 2, "IPv4 forwarding is currently enabled", f"net.ipv4.ip_forward={forward_now or 'unreadable'}")

# Persistent nftables config: /etc/nftables.conf plus any files it includes.
def collect_nft_text(path, seen):
    if path in seen or not os.path.isfile(path):
        return ""
    seen.add(path)
    try:
        text = open(path).read()
    except OSError:
        return ""
    for target in re.findall(r'include\s+"([^"]+)"', text):
        for resolved in sorted(glob.glob(target)):
            text += "\n" + collect_nft_text(resolved, seen)
    return text
nft_text = collect_nft_text("/etc/nftables.conf", set())
persist_ok = "masquerade" in nft_text and subnet in nft_text and wan in nft_text
c3 = criterion("masquerade_persistent", persist_ok, 2,
               "persistent nftables configuration restores the masquerade rule at boot",
               "found subnet, interface and masquerade in /etc/nftables.conf (with includes)" if persist_ok else "rule not found in /etc/nftables.conf or its includes")

enabled = run("systemctl", "is-enabled", "nftables.service")
c4 = criterion("nftables_enabled", enabled == "enabled", 1, "nftables service is enabled at boot", enabled or "unknown")

# Persistent sysctl (last assignment wins, systemd-sysctl precedence).
def sysctl_persisted(key):
    files = {}
    for directory in ("/usr/lib/sysctl.d", "/run/sysctl.d", "/etc/sysctl.d"):
        if os.path.isdir(directory):
            for path in glob.glob(os.path.join(directory, "*.conf")):
                files[os.path.basename(path)] = path
    ordered = [files[name] for name in sorted(files)]
    if os.path.isfile("/etc/sysctl.conf") and "99-sysctl.conf" not in files:
        ordered.append("/etc/sysctl.conf")
    value, source = None, None
    for path in ordered:
        try:
            lines = open(path).read().splitlines()
        except OSError:
            continue
        for raw in lines:
            line = raw.strip()
            if not line or line.startswith(("#", ";")) or "=" not in line:
                continue
            k, v = line.split("=", 1)
            if k.strip().replace("/", ".") == key:
                value, source = v.strip(), path
    return value, source
persist_value, persist_source = sysctl_persisted("net.ipv4.ip_forward")
c5 = criterion("forwarding_persistent", persist_value == "1", 2,
               "IPv4 forwarding is enabled in persistent sysctl configuration",
               f"{persist_source or 'no config file'}: net.ipv4.ip_forward={persist_value or 'unset'}")

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
