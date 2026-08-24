#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/system-proxy-env","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

url = f"http://{p['proxy_host']}:{p['proxy_port']}"
required_no_proxy = {item.strip() for item in p["no_proxy"].split(",") if item.strip()}

env = {}
try:
    lines = open("/etc/environment").read().splitlines()
except OSError:
    lines = []
for raw in lines:
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    if line.startswith("export "):
        line = line[len("export "):].lstrip()
    key, value = line.split("=", 1)
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1]
    env[key.strip()] = value

def value_of(name):
    return env.get(name, env.get(name.upper(), ""))

http_value = value_of("http_proxy")
c1 = criterion("http_proxy", http_value == url, 3,
               "http_proxy points at the required proxy URL", f"http_proxy={http_value or 'unset'}")
https_value = value_of("https_proxy")
c2 = criterion("https_proxy", https_value == url, 3,
               "https_proxy points at the required proxy URL", f"https_proxy={https_value or 'unset'}")
no_proxy_value = value_of("no_proxy")
entries = {item.strip() for item in no_proxy_value.split(",") if item.strip()}
c3 = criterion("no_proxy_entries", required_no_proxy <= entries, 4,
               "no_proxy contains all required exclusions", f"no_proxy={no_proxy_value or 'unset'}")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
