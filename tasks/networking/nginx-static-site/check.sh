#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/nginx-static-site","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, re, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.stdout
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

content_dir = p["content_dir"]
port = int(p["http_port"])
token = p["content_token"]

config = run("nginx", "-T")
listen_re = re.compile(rf"(?m)^\s*listen\s+(?:[^\s;]*:)?{port}\b[^;]*;")
root_re = re.compile(rf"(?m)^\s*root\s+{re.escape(content_dir)}/?\s*;")
listens = bool(listen_re.search(config))
roots = bool(root_re.search(config))
c1 = criterion("config_loaded", listens and roots, 3,
               "nginx configuration serves the content directory on the requested port",
               f"listen:{listens} root:{roots}")

body = run("curl", "-fsS", "-m", "5", f"http://127.0.0.1:{port}/")
c2 = criterion("http_content", token in body, 3,
               "HTTP request on the requested port returns the existing index page",
               (body.strip() or "no HTTP response"))

active = run("systemctl", "is-active", "nginx").strip()
c3 = criterion("service_active", active == "active", 2,
               "nginx service is running", active or "unknown")

enabled = run("systemctl", "is-enabled", "nginx").strip()
c4 = criterion("service_enabled", enabled == "enabled", 2,
               "nginx service starts at boot", enabled or "unknown")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
