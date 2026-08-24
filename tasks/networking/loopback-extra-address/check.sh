#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/loopback-extra-address","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import configparser, glob, json, subprocess, sys

import yaml

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

cidr = p["loopback_address"]
plain_ip, prefix_len = cidr.split("/")
prefix_len = int(prefix_len)

# Active state via ip -j.
try:
    links = json.loads(run("ip", "-j", "addr", "show", "dev", "lo") or "[]")
except json.JSONDecodeError:
    links = []
addr_info = links[0].get("addr_info", []) if links else []
have_extra = any(a.get("local") == plain_ip and a.get("prefixlen") == prefix_len for a in addr_info)
have_base = any(a.get("local") == "127.0.0.1" for a in addr_info)
summary = " ".join(f"{a.get('local')}/{a.get('prefixlen')}" for a in addr_info if a.get("family") == "inet")
c1 = criterion("address_active", have_extra, 4,
               "the additional address is active on lo", summary or "no IPv4 addresses on lo")

# Persistence: netplan stanza for lo, or a systemd-networkd .network file.
def address_matches(value):
    value = str(value)
    return value == cidr or (prefix_len == 32 and value == plain_ip)

persist_source = ""
for path in sorted(glob.glob("/etc/netplan/*.yaml")) + sorted(glob.glob("/etc/netplan/*.yml")):
    try:
        data = yaml.safe_load(open(path)) or {}
    except Exception:
        continue
    network = data.get("network") or {}
    for section_name in ("ethernets", "dummy-devices", "bridges"):
        entry = (network.get(section_name) or {}).get("lo")
        if isinstance(entry, dict) and any(address_matches(a) for a in entry.get("addresses") or []):
            persist_source = f"{path}: {section_name}.lo addresses include {cidr}"
if not persist_source:
    for path in sorted(glob.glob("/etc/systemd/network/*.network")):
        parser = configparser.ConfigParser(strict=False)
        try:
            parser.read(path)
        except (configparser.Error, OSError):
            continue
        name = parser.get("Match", "Name", fallback="")
        if "lo" not in name.split():
            continue
        text = open(path).read()
        for line in text.splitlines():
            line = line.strip()
            if line.startswith("Address") and "=" in line and address_matches(line.split("=", 1)[1].strip()):
                persist_source = f"{path}: Address={line.split('=', 1)[1].strip()}"
c2 = criterion("address_persistent", bool(persist_source), 4,
               "persistent configuration restores the address at boot",
               persist_source or "no netplan or systemd-networkd config found for lo with the address")

c3 = criterion("loopback_intact", have_base, 2,
               "loopback still holds 127.0.0.1", summary or "no IPv4 addresses on lo")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
