#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/vg-add-second-pv","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

disk = p["target_disk"]
vg = p["vg_name"]
part_size = int(p["part_size_mib"])
part2 = f"{disk}2"
part2_vg = run("pvs", "--noheadings", "-o", "vg_name", part2)
c1 = criterion("part2_is_pv", bool(run("pvs", "--noheadings", "-o", "pv_name", part2)), 2, "second partition was initialized as a physical volume", part2_vg or "not a PV")
c2 = criterion("part2_in_vg", part2_vg == vg, 4, "second partition belongs to the requested volume group", part2_vg or "no VG")
count_text = run("vgs", "--noheadings", "-o", "pv_count", vg)
try:
    pv_count = int(count_text)
except ValueError:
    pv_count = 0
c3 = criterion("vg_pv_count", pv_count == 2, 2, "volume group is backed by two physical volumes", count_text or "VG missing")
size_text = run("vgs", "--units", "m", "--nosuffix", "--noheadings", "-o", "vg_size", vg)
try:
    vg_size = float(size_text)
except ValueError:
    vg_size = 0
c4 = criterion("vg_size", vg_size >= 2 * part_size - 16, 2, "volume group capacity covers both partitions", size_text or "unavailable")
criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
