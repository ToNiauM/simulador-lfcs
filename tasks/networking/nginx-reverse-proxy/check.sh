#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"networking/nginx-reverse-proxy","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, re, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.stdout
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

service = p["backend_service"]
backend_port = int(p["backend_port"])
public_port = int(p["public_port"])
token = p["content_token"]

config = run("nginx", "-T")
listen_re = re.compile(rf"(?m)^\s*listen\s+(?:[^\s;]*:)?{public_port}\b[^;]*;")
proxy_re = re.compile(rf"(?m)^\s*proxy_pass\s+http://(?:127\.0\.0\.1|localhost):{backend_port}/?\s*;")
listens = bool(listen_re.search(config))
proxies = bool(proxy_re.search(config))
c1 = criterion("proxy_config", listens and proxies, 3,
               "nginx listens on the public port and forwards to the local backend",
               f"listen:{listens} proxy_pass:{proxies}")

body = run("curl", "-fsS", "-m", "5", f"http://127.0.0.1:{public_port}/")
c2 = criterion("http_via_proxy", token in body, 3,
               "HTTP request on the public port returns the backend content",
               (body.strip() or "no HTTP response"))

nginx_active = run("systemctl", "is-active", "nginx").strip()
nginx_enabled = run("systemctl", "is-enabled", "nginx").strip()
c3 = criterion("nginx_service", nginx_active == "active" and nginx_enabled == "enabled", 2,
               "nginx service is running and starts at boot",
               f"active:{nginx_active or 'unknown'} enabled:{nginx_enabled or 'unknown'}")

backend_active = run("systemctl", "is-active", f"{service}.service").strip()
c4 = criterion("backend_untouched", backend_active == "active", 2,
               "backend service is still running", backend_active or "unknown")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
