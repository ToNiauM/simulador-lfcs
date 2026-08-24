#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/grub-cmdline-param","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import glob, json, os, re, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

param = p["cmdline_param"]

default_ok = False
default_evidence = "/etc/default/grub missing"
if os.path.isfile("/etc/default/grub"):
    default_evidence = "GRUB_CMDLINE_LINUX does not contain the parameter"
    pattern = re.compile(r'^\s*GRUB_CMDLINE_LINUX=(["\']?)(.*?)\1\s*(#.*)?$')
    for line in open("/etc/default/grub"):
        match = pattern.match(line.rstrip("\n"))
        if match:
            default_ok = param in match.group(2).split()
            default_evidence = line.strip()
c1 = criterion("default_grub", default_ok, 3, "parameter present in GRUB_CMDLINE_LINUX in /etc/default/grub", default_evidence)

# Regenerated boot configuration of either family: grub.cfg (Debian or RHEL
# locations, BIOS or EFI) or BLS entries under /boot/loader/entries.
candidates = ["/boot/grub/grub.cfg", "/boot/grub2/grub.cfg"]
candidates += sorted(glob.glob("/boot/efi/EFI/*/grub.cfg"))
candidates += sorted(glob.glob("/boot/loader/entries/*.conf"))
cfg_ok = False
checked = []
cfg_pattern = re.compile(r"(^|[\s\"'])" + re.escape(param) + r"($|[\s\"'])", re.MULTILINE)
cfg_evidence = "no generated boot configuration file found"
for path in candidates:
    if not os.path.isfile(path):
        continue
    checked.append(path)
    if cfg_pattern.search(open(path, errors="replace").read()):
        cfg_ok = True
        cfg_evidence = f"parameter found in {path}"
        break
if not cfg_ok and checked:
    cfg_evidence = "parameter absent from " + ", ".join(checked)
c2 = criterion("grub_cfg", cfg_ok, 3, "boot loader configuration was regenerated with the parameter", cfg_evidence)

try:
    cmdline = open("/proc/cmdline").read().strip()
except OSError:
    cmdline = ""
running_ok = param in cmdline.split()
c3 = criterion("running_cmdline", running_ok, 4, "running kernel booted with the parameter", cmdline or "unreadable /proc/cmdline")

criteria = [c1, c2, c3]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
