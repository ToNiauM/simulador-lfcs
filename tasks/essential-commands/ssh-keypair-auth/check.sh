#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/ssh-keypair-auth","result":"error","score":0,"max_score":8,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":8,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, pwd, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

def home_of(user):
    try:
        return pwd.getpwnam(user).pw_dir
    except KeyError:
        return None

def uid_of(user):
    try:
        return pwd.getpwnam(user).pw_uid
    except KeyError:
        return -1

key_user = p["key_user"]
target_user = p["target_user"]
key_type = p["key_type"]
key_home = home_of(key_user)
target_home = home_of(target_user)
priv = os.path.join(key_home, ".ssh", f"id_{key_type}") if key_home else ""

priv_ok = False
priv_evidence = "private key missing"
if priv and os.path.isfile(priv):
    st = os.stat(priv)
    mode = st.st_mode & 0o777
    priv_ok = mode == 0o600 and st.st_uid == uid_of(key_user)
    priv_evidence = f"{priv} mode {oct(mode)} uid {st.st_uid}"
c1 = criterion("private_key_file", priv_ok, 2,
               "private key exists at the default location with mode 600 owned by the key user", priv_evidence)

pub_line = ""
unencrypted_ok = False
key_evidence = "private key missing"
if priv and os.path.isfile(priv):
    proc = subprocess.run(["ssh-keygen", "-y", "-P", "", "-f", priv],
                          text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if proc.returncode == 0:
        pub_line = proc.stdout.strip()
        unencrypted_ok = pub_line.startswith(f"ssh-{key_type} ")
        key_evidence = pub_line.split()[0] if pub_line else "empty public key"
    else:
        key_evidence = "key is passphrase-protected or unreadable"
c2 = criterion("key_type_no_passphrase", unencrypted_ok, 2,
               "key has the requested type and no passphrase", key_evidence)

auth_path = os.path.join(target_home, ".ssh", "authorized_keys") if target_home else ""
authorized = False
auth_evidence = "authorized_keys missing"
if auth_path and os.path.isfile(auth_path) and pub_line:
    expected_blob = pub_line.split()[:2]
    for line in open(auth_path):
        fields = line.split()
        if len(fields) >= 2 and fields[:2] == expected_blob:
            authorized = True
            auth_evidence = "public key present in authorized_keys"
            break
    else:
        auth_evidence = "public key not found in authorized_keys"
elif auth_path and os.path.isfile(auth_path):
    auth_evidence = "cannot derive public key from private key"
c3 = criterion("key_authorized", authorized, 2,
               "target user's authorized_keys contains the generated public key", auth_evidence)

perms_ok = False
perms_evidence = "target .ssh or authorized_keys missing"
if auth_path and os.path.isfile(auth_path):
    ssh_dir = os.path.dirname(auth_path)
    dir_st = os.stat(ssh_dir)
    file_st = os.stat(auth_path)
    target_uid = uid_of(target_user)
    perms_ok = (dir_st.st_mode & 0o777) == 0o700 and dir_st.st_uid == target_uid \
        and (file_st.st_mode & 0o777) == 0o600 and file_st.st_uid == target_uid
    perms_evidence = f".ssh mode {oct(dir_st.st_mode & 0o777)} uid {dir_st.st_uid}; authorized_keys mode {oct(file_st.st_mode & 0o777)} uid {file_st.st_uid}"
c4 = criterion("target_permissions", perms_ok, 2,
               "target user's .ssh is 700 and authorized_keys is 600, both owned by the target user", perms_evidence)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 8 else "fail", "score": score, "max_score": 8, "criteria": criteria}, separators=(",", ":")))
PY
