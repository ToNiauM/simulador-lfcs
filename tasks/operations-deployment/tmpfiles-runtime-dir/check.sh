#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/tmpfiles-runtime-dir","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, grp, json, os, pwd, stat, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

runtime_dir = p["runtime_dir"].rstrip("/")
owner = p["dir_owner"]
group = p["dir_group"]
expected_mode = int(p["dir_mode"], 8)

def entry_matches(fields):
    if len(fields) < 5 or fields[0] not in ("d", "d!", "D"):
        return False
    if fields[1].rstrip("/") != runtime_dir:
        return False
    try:
        mode_ok = int(fields[2].lstrip("~:"), 8) == expected_mode
    except ValueError:
        mode_ok = False
    return mode_ok and fields[3] == owner and fields[4] == group

conf_line = ""
for path in sorted(glob.glob("/etc/tmpfiles.d/*.conf")):
    try:
        lines = open(path).read().splitlines()
    except OSError:
        continue
    for line in lines:
        if not line.strip() or line.strip().startswith("#"):
            continue
        if entry_matches(line.split()):
            conf_line = f"{path}: {line.strip()}"
c1 = criterion("tmpfiles_conf", bool(conf_line), 2, "a tmpfiles.d configuration declares the directory with the requested owner and mode", conf_line or "no matching entry under /etc/tmpfiles.d")

effective = ""
proc = subprocess.run(["systemd-tmpfiles", "--cat-config"], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
for line in proc.stdout.splitlines():
    if not line.strip() or line.strip().startswith("#"):
        continue
    if entry_matches(line.split()):
        effective = line.strip()
c2 = criterion("tmpfiles_effective", bool(effective), 2, "systemd-tmpfiles effective configuration contains the requested entry", effective or "entry absent from systemd-tmpfiles --cat-config")

is_dir = os.path.isdir(runtime_dir)
c3 = criterion("dir_exists", is_dir, 2, "runtime directory currently exists", runtime_dir if is_dir else f"{runtime_dir} missing")

owner_ok = False
owner_evidence = "directory missing"
mode_ok = False
mode_evidence = "directory missing"
if is_dir:
    st = os.stat(runtime_dir)
    try:
        actual_owner = pwd.getpwuid(st.st_uid).pw_name
    except KeyError:
        actual_owner = str(st.st_uid)
    try:
        actual_group = grp.getgrgid(st.st_gid).gr_name
    except KeyError:
        actual_group = str(st.st_gid)
    owner_ok = actual_owner == owner and actual_group == group
    owner_evidence = f"{actual_owner}:{actual_group}"
    actual_mode = stat.S_IMODE(st.st_mode)
    mode_ok = actual_mode == expected_mode
    mode_evidence = oct(actual_mode)
c4 = criterion("dir_ownership", owner_ok, 2, "runtime directory has the requested owner and group", owner_evidence)
c5 = criterion("dir_mode", mode_ok, 2, "runtime directory has the requested permissions", mode_evidence)

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
