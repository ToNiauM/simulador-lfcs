#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"users-groups/skel-onboarding","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, pwd, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}
def read_line(path):
    try:
        return open(path).read().rstrip("\n")
    except OSError:
        return None

skel_path = os.path.join("/etc/skel", p["skel_file"])
expected = p["skel_content"]
skel_text = read_line(skel_path)
c1 = criterion("skel_file", skel_text == expected, 3, "template file exists in /etc/skel with the exact content", skel_text if skel_text is not None else "file missing")
try:
    entry = pwd.getpwnam(p["username"])
except KeyError:
    entry = None
c2 = criterion("user_created", entry is not None and os.path.isdir(entry.pw_dir), 2, "user exists and has a home directory", entry.pw_dir if entry else "user missing")
home_copy = os.path.join(entry.pw_dir, p["skel_file"]) if entry else ""
home_text = read_line(home_copy) if entry else None
c3 = criterion("inherited_file", entry is not None and os.path.isfile(home_copy), 2, "user's home contains a copy of the template file", home_copy or "user missing")
c4 = criterion("inherited_content", home_text == expected, 2, "inherited copy has the exact content", home_text if home_text is not None else "file missing")
owner_ok = False
owner_evidence = "file missing"
if entry is not None and os.path.isfile(home_copy):
    st = os.stat(home_copy)
    owner_ok = st.st_uid == entry.pw_uid
    owner_evidence = f"owner uid={st.st_uid}, user uid={entry.pw_uid}"
c5 = criterion("inherited_owner", owner_ok, 1, "inherited copy is owned by the user", owner_evidence)
criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
