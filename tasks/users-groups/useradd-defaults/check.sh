#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"users-groups/useradd-defaults","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, pwd, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

defaults = {}
try:
    for line in open("/etc/default/useradd"):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, value = line.partition("=")
            defaults[key.strip()] = value.strip().strip('"')
except OSError:
    pass
c1 = criterion("default_shell", defaults.get("SHELL") == p["default_shell"], 3, "default login shell for new users matches", f"SHELL={defaults.get('SHELL', 'unset')}")
c2 = criterion("default_base_dir", defaults.get("HOME") == p["base_dir"], 3, "default home base directory for new users matches", f"HOME={defaults.get('HOME', 'unset')}")
try:
    entry = pwd.getpwnam(p["username"])
except KeyError:
    entry = None
c3 = criterion("user_shell", entry is not None and entry.pw_shell == p["default_shell"], 2, "new user's login shell demonstrates the default", entry.pw_shell if entry else "user missing")
expected_home = os.path.join(p["base_dir"], p["username"])
home_ok = entry is not None and entry.pw_dir == expected_home and os.path.isdir(expected_home)
c4 = criterion("user_home", home_ok, 2, "new user's home directory lives under the new base directory", entry.pw_dir if entry else "user missing")
criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
