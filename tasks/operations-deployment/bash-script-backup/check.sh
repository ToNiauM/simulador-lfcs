#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/bash-script-backup","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys, tarfile, tempfile

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

script_path = p["script_path"]
prefix = p["archive_prefix"]
source_dir = p["source_dir"].rstrip("/")
token = p["data_token"]

expected_files = {
    "report.txt": f"report {token}\nline two of the report\n",
    "data.csv": f"id,value\n1,{token[0:8]}\n2,{token[8:16]}\n",
    "logs/notes.log": f"entry {token}\n",
}

exists = os.path.isfile(script_path)
executable = exists and os.access(script_path, os.X_OK)
c1 = criterion("script_executable", executable, 2, "script exists and is executable", script_path if executable else f"{script_path} missing or not executable")

archive_name = f"{prefix}-{os.path.basename(source_dir)}.tar.gz"
run_ok = False
run_evidence = "script not runnable"
archive_path = ""
tar_ok = False
tar_evidence = "archive not created"
content_ok = False
content_evidence = "archive not created"

# Running the candidate script against the fixture is the read of its final
# behavior; all writes go to a throwaway temporary directory.
with tempfile.TemporaryDirectory(prefix="lfcs-backup-check-") as dest:
    if executable and os.path.isdir(source_dir):
        try:
            proc = subprocess.run([script_path, source_dir, dest], text=True, capture_output=True, timeout=30)
        except (OSError, subprocess.TimeoutExpired):
            proc = None
        if proc is not None:
            candidate = os.path.join(dest, archive_name)
            run_ok = proc.returncode == 0 and os.path.isfile(candidate)
            created = sorted(os.listdir(dest))
            run_evidence = f"rc={proc.returncode}; created: {', '.join(created) or 'nothing'} (expected {archive_name})"
            if os.path.isfile(candidate):
                archive_path = candidate
    elif executable:
        run_evidence = f"fixture directory {source_dir} missing"

    if archive_path:
        try:
            with tarfile.open(archive_path, "r:gz") as tar:
                names = tar.getnames()
                found = {}
                for member in tar.getmembers():
                    if not member.isfile():
                        continue
                    normalized = member.name.lstrip("./")
                    for rel in expected_files:
                        if normalized == rel or normalized.endswith("/" + rel):
                            found[rel] = tar.extractfile(member).read().decode(errors="replace")
                tar_ok = set(found) == set(expected_files)
                tar_evidence = f"members: {', '.join(names[:8])}"
                if tar_ok:
                    mismatched = [rel for rel, text in found.items() if text != expected_files[rel]]
                    content_ok = not mismatched
                    content_evidence = "all file contents match the source" if content_ok else f"content mismatch: {', '.join(mismatched)}"
                else:
                    missing = sorted(set(expected_files) - set(found))
                    tar_evidence = f"missing from archive: {', '.join(missing)}; members: {', '.join(names[:6])}"
                    content_evidence = "expected files missing from archive"
        except (tarfile.TarError, OSError, EOFError) as exc:
            tar_evidence = f"not a readable gzip tar archive: {exc}"
            content_evidence = tar_evidence

c2 = criterion("script_creates_archive", run_ok, 3, "script exits successfully and creates the archive with the required name", run_evidence)
c3 = criterion("archive_contents_listed", tar_ok, 2, "archive is a gzip tar containing all source files", tar_evidence)
c4 = criterion("archive_contents_intact", content_ok, 3, "archived file contents match the source files", content_evidence)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
