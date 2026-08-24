#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/mtu-custom","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import configparser, glob, json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.stdout
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

nic = p["nic"]
expected_mtu = int(p["mtu"])

try:
    links = json.loads(run("ip", "-j", "link", "show", "dev", nic) or "[]")
except json.JSONDecodeError:
    links = []
link = links[0] if links else {}
up = "UP" in link.get("flags", [])
c1 = criterion("link_up", bool(link) and up, 2, "interface exists and is up",
               ",".join(link.get("flags", [])) if link else "interface not found")

actual_mtu = link.get("mtu")
c2 = criterion("mtu_active", actual_mtu == expected_mtu, 4,
               "requested MTU is active on the interface",
               f"mtu:{actual_mtu if actual_mtu is not None else 'unknown'}")

persist = ""
try:
    import yaml
    for path in sorted(glob.glob("/etc/netplan/*.yaml")):
        try:
            node = yaml.safe_load(open(path)) or {}
        except Exception:
            continue
        ethernets = ((node.get("network", {}) or {}).get("ethernets", {}) or {})
        cfg = ethernets.get(nic) or {}
        if cfg.get("mtu") == expected_mtu:
            persist = f"netplan:{path}"
except ImportError:
    pass
if not persist:
    # NetworkManager keyfiles (RHEL family): an ethernet profile bound to the
    # NIC whose [ethernet]/[802-3-ethernet] section sets the requested MTU.
    for path in sorted(glob.glob("/etc/NetworkManager/system-connections/*")):
        if not os.path.isfile(path):
            continue
        parser = configparser.ConfigParser(strict=False, interpolation=None)
        try:
            parser.read(path)
        except Exception:
            continue
        if not parser.has_section("connection"):
            continue
        if parser.get("connection", "type", fallback="") not in ("ethernet", "802-3-ethernet"):
            continue
        if parser.get("connection", "interface-name", fallback="") != nic:
            continue
        kf_mtu = ""
        for section in ("ethernet", "802-3-ethernet"):
            if parser.has_section(section):
                kf_mtu = parser.get(section, "mtu", fallback="") or kf_mtu
        if kf_mtu.strip() == str(expected_mtu):
            persist = f"nm-keyfile:{path}"
c3 = criterion("netplan_persistent", bool(persist), 4,
               "a persistent network configuration file sets the requested MTU on the interface",
               persist or "no netplan or NetworkManager configuration sets the MTU")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
