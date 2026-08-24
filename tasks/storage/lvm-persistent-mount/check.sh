#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"storage/lvm-persistent-mount","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def run(*args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

vg = p["vg_name"]
lv = p["lv_name"]
disk = p["target_disk"]
mount_point = p["mount_point"]
expected_size = int(p["lv_size_mib"])
fs = p["filesystem"]
actual_vg = run("pvs", "--noheadings", "-o", "vg_name", disk)
c1 = criterion("pv_in_vg", actual_vg == vg, 2, "disco pertence ao VG solicitado", actual_vg or "PV/VG ausente")
lv_path = run("lvs", "--noheadings", "-o", "lv_path", f"{vg}/{lv}")
c2 = criterion("lv_exists", bool(lv_path), 2, "logical volume solicitado existe", lv_path or "LV ausente")
size_text = run("lvs", "--units", "m", "--nosuffix", "--noheadings", "-o", "lv_size", f"{vg}/{lv}") if lv_path else ""
try:
    actual_size = float(size_text)
except ValueError:
    actual_size = 0
c3 = criterion("lv_size", expected_size <= actual_size < expected_size + 5, 2, "tamanho do LV corresponde ao solicitado", size_text or "indisponível")
active_source = run("findmnt", "-no", "SOURCE", "--target", mount_point)
active_fs = run("findmnt", "-no", "FSTYPE", "--target", mount_point)
c4 = criterion("mounted_filesystem", bool(active_source) and active_fs == fs, 2, "filesystem está montado no destino", f"{active_source or 'não montado'} ({active_fs or '-'})")
persistent = False
evidence = "entrada correspondente ausente"
if lv_path and os.path.exists("/etc/fstab"):
    lv_real = os.path.realpath(lv_path)
    uuid = run("blkid", "-s", "UUID", "-o", "value", lv_path)
    for line in open("/etc/fstab"):
        fields = line.split()
        if len(fields) < 3 or fields[0].startswith("#") or fields[1] != mount_point or fields[2] != fs:
            continue
        source = fields[0]
        source_matches = source == f"UUID={uuid}" or (not source.startswith("UUID=") and os.path.realpath(source) == lv_real)
        if source_matches:
            persistent = True
            evidence = line.strip()
            break
c5 = criterion("persistent_fstab", persistent, 2, "fstab restaura a montagem", evidence)
criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
