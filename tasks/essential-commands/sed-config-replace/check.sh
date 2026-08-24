#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/sed-config-replace","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

conf = p["conf_file"]
exists = os.path.isfile(conf)
c1 = criterion("config_exists", exists, 1, "configuration file still exists at the same path",
               conf if exists else "file missing")

def active_values(key):
    values = []
    if exists:
        with open(conf) as handle:
            for line in handle:
                line = line.strip()
                if line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                if k.strip() == key:
                    values.append(v.strip())
    return values

ports = active_values("port")
port_ok = ports == [str(p["new_port"])]
c2 = criterion("port_updated", port_ok, 3, "key 'port' holds exactly the requested value",
               "port=" + ",".join(ports) if ports else "key 'port' absent")

levels = active_values("log_level")
level_ok = levels == [p["new_log_level"]]
c3 = criterion("log_level_updated", level_ok, 3, "key 'log_level' holds exactly the requested value",
               "log_level=" + ",".join(levels) if levels else "key 'log_level' absent")

expected_untouched = {
    "listen_addr": str(p["listen_addr"]),
    "max_clients": str(p["max_clients"]),
    "workers": str(p["workers"]),
    "data_dir": str(p["data_dir"]),
}
wrong = []
for key, value in expected_untouched.items():
    if active_values(key) != [value]:
        wrong.append(key)
untouched_ok = exists and not wrong
c4 = criterion("other_keys_untouched", untouched_ok, 3, "all other keys keep their original values",
               "unchanged" if untouched_ok else "altered/missing keys: " + ", ".join(wrong) if wrong else "file missing")

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
