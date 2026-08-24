#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/diff-patch-apply","result":"error","score":0,"max_score":6,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":6,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

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
conf_path = os.path.join(work_dir, p["conf_name"])
notes_path = os.path.join(work_dir, p["notes_name"])
keep_path = os.path.join(work_dir, p["keep_name"])

conf_data = read(conf_path)
conf_ok = conf_data == p["conf_expected"] + "\n"
c1 = criterion("conf_patched", conf_ok, 2,
               "configuration file matches the post-patch content exactly",
               "patched content matches" if conf_ok else ("file missing" if conf_data is None else "content differs from post-patch state"))

notes_data = read(notes_path)
notes_ok = notes_data == p["notes_expected"] + "\n"
c2 = criterion("notes_patched", notes_ok, 2,
               "notes file matches the post-patch content exactly",
               "patched content matches" if notes_ok else ("file missing" if notes_data is None else "content differs from post-patch state"))

keep_ok = read(keep_path) == p["keep_content"] + "\n"
c3 = criterion("untouched_file_intact", keep_ok, 1,
               "file not mentioned by the patch is unchanged",
               "unchanged" if keep_ok else f"{p['keep_name']} missing or modified")

junk = sorted(os.path.basename(f)
              for pattern in ("*.rej", "*.orig")
              for f in glob.glob(os.path.join(work_dir, "**", pattern), recursive=True))
patch_present = os.path.isfile(p["patch_file"])
clean_ok = not junk and patch_present
c4 = criterion("clean_apply", clean_ok, 1,
               "patch applied cleanly: no reject or backup files remain and the patch file is kept",
               "clean" if clean_ok else ("leftovers: " + ", ".join(junk) if junk else "patch file was deleted"))

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 6 else "fail", "score": score, "max_score": 6, "criteria": criteria}, separators=(",", ":")))
PY
