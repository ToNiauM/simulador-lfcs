#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/lvm-snapshot","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

vg = p["vg_name"]
origin = p["origin_lv"]
snap = p["snap_name"]
expected_size = int(p["snap_size_mib"])
row = run("lvs", "--noheadings", "--separator", "|", "-o", "lv_attr,origin", f"{vg}/{snap}")
attr, snap_origin = (row.split("|") + ["", ""])[:2] if row else ("", "")
attr = attr.strip()
snap_origin = snap_origin.strip()
c1 = criterion("snap_exists", bool(row), 2, "requested snapshot volume exists", row.strip() or "LV missing")
c2 = criterion("snap_is_snapshot", bool(attr) and attr[0] == "s", 3, "volume is a valid active snapshot", attr or "no attributes")
c3 = criterion("snap_origin", snap_origin == origin, 3, f"snapshot origin is {origin}", snap_origin or "no origin")
size_text = run("lvs", "--units", "m", "--nosuffix", "--noheadings", "-o", "lv_size", f"{vg}/{snap}") if row else ""
try:
    snap_size = float(size_text)
except ValueError:
    snap_size = 0
c4 = criterion("snap_size", expected_size <= snap_size < expected_size + 8, 2, f"snapshot reserves {expected_size} MiB", size_text or "unavailable")
criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
