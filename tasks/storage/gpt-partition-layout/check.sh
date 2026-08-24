#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/gpt-partition-layout","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

disk = p["target_disk"]
expected = (int(p["part1_size_mib"]), int(p["part2_size_mib"]))
try:
    table = json.loads(run("sfdisk", "-J", disk)).get("partitiontable", {})
except (ValueError, TypeError):
    table = {}
label = table.get("label", "")
sector = int(table.get("sectorsize", 512) or 512)
parts = sorted(table.get("partitions", []), key=lambda item: item.get("start", 0))
sizes = [round(item.get("size", 0) * sector / 1048576, 1) for item in parts]
c1 = criterion("gpt_label", label == "gpt", 2, "disk uses a GPT partition table", label or "no partition table")
c2 = criterion("partition_count", len(parts) == 2, 2, "disk holds exactly two partitions", f"{len(parts)} partition(s): {sizes}")
c3 = criterion("part1_size", len(sizes) >= 1 and abs(sizes[0] - expected[0]) <= 4, 3, f"first partition is {expected[0]} MiB", f"{sizes[0]} MiB" if sizes else "missing")
c4 = criterion("part2_size", len(sizes) >= 2 and abs(sizes[1] - expected[1]) <= 4, 3, f"second partition is {expected[1]} MiB", f"{sizes[1]} MiB" if len(sizes) >= 2 else "missing")
criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
