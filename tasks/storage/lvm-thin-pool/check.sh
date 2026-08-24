#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/lvm-thin-pool","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

vg = p["vg_name"]
pool = p["pool_name"]
thin = p["thin_lv_name"]
pool_size = int(p["pool_size_mib"])
virtual_size = int(p["thin_virtual_size_mib"])
def lv_row(name):
    row = run("lvs", "--noheadings", "--separator", "|", "--units", "m", "--nosuffix", "-o", "lv_attr,lv_size,pool_lv", f"{vg}/{name}")
    fields = [item.strip() for item in row.split("|")] if row else []
    return (fields + ["", "", ""])[:3]
pool_attr, pool_size_text, _ = lv_row(pool)
thin_attr, thin_size_text, thin_pool = lv_row(thin)
def as_float(text):
    try:
        return float(text)
    except ValueError:
        return 0.0
c1 = criterion("pool_is_thin_pool", bool(pool_attr) and pool_attr[0] == "t", 2, "requested thin pool exists", pool_attr or "pool LV missing")
c2 = criterion("pool_size", pool_size <= as_float(pool_size_text) < pool_size + 8, 2, f"thin pool size is {pool_size} MiB", pool_size_text or "unavailable")
c3 = criterion("thin_is_thin_volume", bool(thin_attr) and thin_attr[0] == "V", 2, "requested thin volume exists and is thin-provisioned", thin_attr or "thin LV missing")
c4 = criterion("thin_in_pool", thin_pool == pool, 2, "thin volume is backed by the requested pool", thin_pool or "no pool")
c5 = criterion("thin_virtual_size", virtual_size <= as_float(thin_size_text) < virtual_size + 8, 2, f"thin volume virtual size is {virtual_size} MiB", thin_size_text or "unavailable")
criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
