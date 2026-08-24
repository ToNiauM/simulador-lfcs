#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"operations-deployment/quadlet-container-unit","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

container_file = p["container_file"]
image = p["image"]
publish = f"{p['host_port']}:{p['container_port']}"
env_pair = f"{p['env_name']}={p['env_value']}"

sections = {}
file_evidence = f"{container_file} missing"
if os.path.isfile(container_file):
    section = ""
    for line in open(container_file):
        text = line.split("#", 1)[0].strip() if not line.lstrip().startswith(";") else ""
        if not text:
            continue
        if text.startswith("[") and text.endswith("]"):
            section = text[1:-1].strip().lower()
            continue
        if "=" in text:
            key, value = (part.strip() for part in text.split("=", 1))
            sections.setdefault(section, []).append((key.lower(), value))
    file_evidence = "; ".join(f"{k}={v}" for k, v in sections.get("container", [])) or "no [Container] settings found"

container = sections.get("container", [])
image_ok = any(k == "image" and v == image for k, v in container)
c1 = criterion("quadlet_image", image_ok, 3, "Quadlet file declares the required Image", file_evidence)

def publish_matches(value):
    fields = value.split(":")
    return len(fields) >= 2 and fields[-2] == str(p["host_port"]) and fields[-1] == str(p["container_port"])
publish_ok = any(k == "publishport" and publish_matches(v) for k, v in container)
c2 = criterion("quadlet_publish", publish_ok, 2, "Quadlet file publishes the required port mapping", file_evidence)

env_ok = any(k == "environment" and env_pair in v.split() for k, v in container)
c3 = criterion("quadlet_environment", env_ok, 2, "Quadlet file sets the required environment variable", file_evidence)

generator = "/usr/lib/systemd/system-generators/podman-system-generator"
gen_ok = False
gen_evidence = f"{generator} missing"
if os.access(generator, os.X_OK):
    proc = subprocess.run([generator, "--dryrun"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    service = f"{p['unit_basename']}.service"
    gen_ok = proc.returncode == 0 and service in proc.stdout and image in proc.stdout
    gen_evidence = f"exit={proc.returncode}; {service} {'generated' if service in proc.stdout else 'not generated'}"
c4 = criterion("generator_dryrun", gen_ok, 3, "podman system generator produces the service unit", gen_evidence)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
