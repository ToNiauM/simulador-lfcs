#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/timezone-locale","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}
def normalize(locale):
    return locale.lower().replace("-", "")

tz = p["timezone"]
locale = p["locale"]

active_tz = run("timedatectl", "show", "-p", "Timezone", "--value")
c1 = criterion("timezone_active", active_tz == tz, 3, "system timezone is set", active_tz or "unknown")

localtime = os.path.realpath("/etc/localtime") if os.path.exists("/etc/localtime") else ""
link_ok = localtime.endswith("/zoneinfo/" + tz)
c2 = criterion("localtime_link", link_ok, 2, "/etc/localtime points at the requested zone", localtime or "/etc/localtime missing")

available = {normalize(entry) for entry in run("locale", "-a").split()}
gen_ok = normalize(locale) in available
c3 = criterion("locale_generated", gen_ok, 3, "requested locale is generated", locale if gen_ok else f"{locale} not in locale -a")

# Persistent default LANG: /etc/default/locale (Debian) or /etc/locale.conf (RHEL).
lang_ok = False
lang_evidence = "neither /etc/default/locale nor /etc/locale.conf sets LANG"
for path in ("/etc/default/locale", "/etc/locale.conf"):
    if lang_ok or not os.path.isfile(path):
        continue
    for line in open(path):
        text = line.split("#", 1)[0].strip()
        if text.startswith("LANG="):
            lang = text.split("=", 1)[1].strip().strip('"').strip("'")
            lang_evidence = f"{path}: {text}"
            if normalize(lang) == normalize(locale):
                lang_ok = True
                break
c4 = criterion("default_lang", lang_ok, 2, "requested locale is the default LANG", lang_evidence)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
