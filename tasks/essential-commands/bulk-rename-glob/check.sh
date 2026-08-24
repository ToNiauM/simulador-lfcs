#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/bulk-rename-glob","result":"error","score":0,"max_score":5,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":5,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

def read(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return None

work_dir = p["work_dir"]
prefix = p["prefix"]
old_ext = p["old_ext"]
new_ext = p["new_ext"]
count = int(p["count"])
lot_id = p["lot_id"]

leftovers = sorted(os.path.basename(f) for f in glob.glob(os.path.join(work_dir, f"{prefix}-*.{old_ext}")))
c1 = criterion("old_names_gone", not leftovers, 2,
               "no file with the old extension remains",
               "no old-extension files left" if not leftovers else "still present: " + ", ".join(leftovers))

bad = []
for i in range(1, count + 1):
    stem = f"{prefix}-{i:02d}"
    data = read(os.path.join(work_dir, f"{stem}.{new_ext}"))
    if data != f"registro {stem} lote {lot_id}\n":
        bad.append(f"{stem}.{new_ext}")
c2 = criterion("new_names_content", not bad, 2,
               "every renamed file exists with the new extension and unchanged content",
               "all renamed files intact" if not bad else "missing or altered: " + ", ".join(bad))

keep_path = os.path.join(work_dir, p["keep_file"])
keep_ok = read(keep_path) == f"resumo do lote {lot_id}\n"
c3 = criterion("other_files_untouched", keep_ok, 1,
               "unrelated files were left untouched",
               "unrelated file intact" if keep_ok else f"{p['keep_file']} missing or modified")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 5 else "fail", "score": score, "max_score": 5, "criteria": criteria}, separators=(",", ":")))
PY
