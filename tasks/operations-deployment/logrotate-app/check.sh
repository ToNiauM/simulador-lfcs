#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/logrotate-app","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import fnmatch, json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

config = "/etc/logrotate.d/" + p["app_name"]
log_path = p["log_path"]

# Parse the config into blocks: header patterns + directive lines.
blocks = []
if os.path.isfile(config):
    header, body, depth = [], [], 0
    for raw in open(config):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if depth == 0:
            if line.endswith("{"):
                header.extend(line[:-1].split())
                depth = 1
            else:
                header.extend(line.split())
        else:
            if line == "}":
                blocks.append((header, body))
                header, body, depth = [], [], 0
            else:
                body.append(line.split())

block = None
for header, body in blocks:
    if any(pattern == log_path or fnmatch.fnmatch(log_path, pattern) for pattern in header):
        block = body
        break
c1 = criterion("config_targets_log", block is not None, 2,
               "logrotate config file covers the application log",
               config if block is not None else f"{config}: no block matching {log_path}")

body = block or []
directives = {line[0] for line in body}
c2 = criterion("weekly_rotation", "weekly" in directives and not directives & {"daily", "monthly", "yearly"}, 2,
               "log is rotated weekly", ", ".join(sorted(directives & {"daily", "weekly", "monthly", "yearly"})) or "no rotation interval")

rotate_lines = [line for line in body if line[0] == "rotate" and len(line) == 2]
rotate_ok = any(line[1] == str(p["rotate_count"]) for line in rotate_lines)
c3 = criterion("rotate_count", rotate_ok, 2,
               "requested number of rotations is kept",
               " ".join(rotate_lines[0]) if rotate_lines else "no rotate directive")

def mode_equal(a, b):
    try:
        return int(a, 8) == int(b, 8)
    except ValueError:
        return False
create_lines = [line for line in body if line[0] == "create" and len(line) == 4]
create_ok = any(mode_equal(line[1], p["create_mode"]) and line[2] == p["create_user"] and line[3] == p["create_group"] for line in create_lines)
c4 = criterion("compress_and_create", "compress" in directives and create_ok, 2,
               "rotated logs are compressed and the log is recreated with the requested ownership and mode",
               ("compress; " if "compress" in directives else "no compress; ") + (" ".join(create_lines[0]) if create_lines else "no create directive"))

proc = subprocess.run(["logrotate", "-d", config], text=True, capture_output=True)
output = (proc.stdout + proc.stderr).lower()
dry_ok = os.path.isfile(config) and proc.returncode == 0 and "error" not in output
c5 = criterion("dry_run_clean", dry_ok, 2,
               "logrotate accepts the configuration without errors",
               f"rc={proc.returncode}" if os.path.isfile(config) else "config file missing")

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
