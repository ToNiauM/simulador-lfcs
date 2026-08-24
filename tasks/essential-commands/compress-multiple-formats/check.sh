#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/compress-multiple-formats","result":"error","score":0,"max_score":6,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":6,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import gzip, json, lzma, os, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

def read_bytes(path):
    try:
        with open(path, "rb") as handle:
            return handle.read()
    except OSError:
        return None

work_dir = p["work_dir"]
gzip_path = os.path.join(work_dir, p["gzip_file"])
xz_path = os.path.join(work_dir, p["xz_file"])
expected_gzip = (p["gzip_content"] + "\n").encode()
expected_xz = (p["xz_content"] + "\n").encode()

originals_ok = read_bytes(gzip_path) == expected_gzip and read_bytes(xz_path) == expected_xz
c1 = criterion("originals_intact", originals_ok, 2,
               "both original files are still present and unchanged",
               "originals unchanged" if originals_ok else "an original file is missing or was modified")

gz_data = read_bytes(gzip_path + ".gz")
gz_ok = False
gz_evidence = "gzip file missing"
if gz_data is not None:
    if not gz_data.startswith(b"\x1f\x8b"):
        gz_evidence = "wrong magic: not a gzip file"
    else:
        try:
            gz_ok = gzip.decompress(gz_data) == expected_gzip
            gz_evidence = "valid gzip with original content" if gz_ok else "gzip content differs from original"
        except OSError:
            gz_evidence = "corrupt gzip stream"
c2 = criterion("gzip_archive", gz_ok, 2,
               "gzip copy exists, is real gzip and matches the original content", gz_evidence)

xz_data = read_bytes(xz_path + ".xz")
xz_ok = False
xz_evidence = "xz file missing"
if xz_data is not None:
    if not xz_data.startswith(b"\xfd7zXZ\x00"):
        xz_evidence = "wrong magic: not an xz file"
    else:
        try:
            xz_ok = lzma.decompress(xz_data) == expected_xz
            xz_evidence = "valid xz with original content" if xz_ok else "xz content differs from original"
        except lzma.LZMAError:
            xz_evidence = "corrupt xz stream"
c3 = criterion("xz_archive", xz_ok, 2,
               "xz copy exists, is real xz and matches the original content", xz_evidence)

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 6 else "fail", "score": score, "max_score": 6, "criteria": criteria}, separators=(",", ":")))
PY
