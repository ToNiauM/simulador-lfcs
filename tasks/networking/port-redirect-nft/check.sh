#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/port-redirect-nft","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, os, re, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.stdout
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

table = p["nft_table"]
src_port = int(p["src_port"])
dst_port = int(p["dst_port"])

try:
    ruleset = json.loads(run("nft", "-j", "list", "ruleset") or "{}").get("nftables", [])
except json.JSONDecodeError:
    ruleset = []

tables = [i["table"] for i in ruleset if "table" in i
          and i["table"]["name"] == table and i["table"]["family"] in ("ip", "inet")]
c1 = criterion("table_exists", bool(tables), 2,
               "requested nftables table exists (family ip or inet)",
               ", ".join(f"{t['family']} {t['name']}" for t in tables) or "table not found")

nat_chains = set()
for item in ruleset:
    chain = item.get("chain")
    if chain and chain["table"] == table and chain.get("type") == "nat" and chain.get("hook") == "prerouting":
        nat_chains.add((chain["family"], chain["name"]))
c2 = criterion("nat_prerouting_chain", bool(nat_chains), 2,
               "table contains a nat chain hooked to prerouting",
               ", ".join(f"{f}/{n}" for f, n in sorted(nat_chains)) or "no nat prerouting chain")

def rule_matches(expr):
    has_dport = any(
        e.get("match", {}).get("left", {}).get("payload", {}).get("field") == "dport"
        and e["match"].get("left", {}).get("payload", {}).get("protocol") == "tcp"
        and e["match"].get("right") == src_port
        for e in expr)
    has_redirect = any(
        "redirect" in e and (e["redirect"] or {}).get("port") == dst_port
        for e in expr)
    return has_dport and has_redirect

matched = ""
for item in ruleset:
    rule = item.get("rule")
    if rule and rule["table"] == table and (rule["family"], rule["chain"]) in nat_chains and rule_matches(rule.get("expr", [])):
        matched = f"{rule['family']} {rule['table']} {rule['chain']} handle {rule.get('handle')}"
        break
c3 = criterion("redirect_rule", bool(matched), 3,
               "active rule redirects the requested TCP port to the local port",
               matched or "no matching redirect rule in the running ruleset")

conf_files = ["/etc/nftables.conf"]
text_by_file = {}
seen = set()
while conf_files:
    path = conf_files.pop(0)
    for real in sorted(glob.glob(path)):
        if real in seen or not os.path.isfile(real):
            continue
        seen.add(real)
        try:
            text = open(real).read()
        except OSError:
            continue
        text_by_file[real] = text
        conf_files.extend(re.findall(r'(?m)^\s*include\s+"([^"]+)"', text))
persist_file = ""
for real, text in text_by_file.items():
    if re.search(rf"dport\s+{src_port}\b", text) and re.search(rf"redirect\s+to\s+:?{dst_port}\b", text):
        persist_file = real
        break
enabled = run("systemctl", "is-enabled", "nftables.service").strip()
c4 = criterion("persistent", bool(persist_file) and enabled == "enabled", 3,
               "redirect is stored in the boot-time nftables configuration and the nftables service is enabled",
               f"config:{persist_file or 'not found'} nftables:{enabled or 'unknown'}")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
