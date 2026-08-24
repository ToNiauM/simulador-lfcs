#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/nftables-block-source","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, os, re, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

subnet = p["blocked_subnet"]
addr, _, length = subnet.partition("/")
length = int(length)

def subnet_matches(right):
    if isinstance(right, str):
        return right == subnet
    if isinstance(right, dict):
        prefix = right.get("prefix")
        if prefix:
            return prefix.get("addr") == addr and int(prefix.get("len", -1)) == length
        if "set" in right:
            return any(subnet_matches(item) for item in right["set"])
    return False

ruleset_json = run("nft", "-j", "list", "ruleset")
active_ok = False
active_evidence = "no matching drop rule in an input-hook chain"
try:
    objects = json.loads(ruleset_json or "{}").get("nftables", [])
    input_chains = set()
    for obj in objects:
        chain = obj.get("chain")
        if chain and chain.get("hook") == "input":
            input_chains.add((chain.get("family"), chain.get("table"), chain.get("name")))
    for obj in objects:
        rule = obj.get("rule")
        if not rule or (rule.get("family"), rule.get("table"), rule.get("chain")) not in input_chains:
            continue
        has_subnet = False
        has_drop = False
        for expr in rule.get("expr", []):
            match = expr.get("match")
            if match:
                left = match.get("left", {})
                payload_expr = left.get("payload", {}) if isinstance(left, dict) else {}
                if payload_expr.get("field") == "saddr" and subnet_matches(match.get("right")):
                    has_subnet = True
            if "drop" in expr:
                has_drop = True
        if has_subnet and has_drop:
            active_ok = True
            active_evidence = json.dumps(rule.get("expr"))[:200]
            break
except ValueError:
    active_evidence = "nft -j list ruleset unavailable"
c1 = criterion("rule_active", active_ok, 4, "running ruleset drops traffic sourced from the blocked network", active_evidence)

def config_text(path, seen):
    if path in seen or not os.path.isfile(path):
        return ""
    seen.add(path)
    text = open(path).read()
    for included in re.findall(r'^\s*include\s+"([^"]+)"', text, re.MULTILINE):
        for sub in sorted(glob.glob(included)):
            text += "\n" + config_text(sub, seen)
    return text

text = config_text("/etc/nftables.conf", set())
text = re.sub(r"#[^\n]*", "", text)
subnet_pattern = re.compile(r"saddr\s+(?:\{[^}]*" + re.escape(subnet) + r"[^}]*\}|" + re.escape(subnet) + r")[^\n;]*\bdrop\b")
match = subnet_pattern.search(text)
c2 = criterion("rule_persistent", bool(match), 3, "persistent nftables configuration contains the drop rule", match.group(0) if match else "rule not found in /etc/nftables.conf or its includes")

enabled = run("systemctl", "is-enabled", "nftables") or run("systemctl", "is-enabled", "nftables.service")
c3 = criterion("service_enabled", enabled == "enabled", 3, "nftables service loads the ruleset at boot", enabled or "nftables service not found")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
