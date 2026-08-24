#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"users-groups/group-membership","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import grp, json, pwd, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]
def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}
def supplementary(user):
    out = subprocess.run(["id", "-nG", user], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
    return out.split() if out else []
def primary_group(user):
    try:
        return grp.getgrgid(pwd.getpwnam(user).pw_gid).gr_name
    except KeyError:
        return ""

group_a, group_b = p["group_a"], p["group_b"]
user_one, user_two = p["user_one"], p["user_two"]
groups_exist = all(bool(subprocess.run(["getent", "group", g], stdout=subprocess.DEVNULL).returncode == 0) for g in (group_a, group_b))
c1 = criterion("groups_exist", groups_exist, 2, "both requested groups exist", f"{group_a},{group_b} lookup")
m1 = supplementary(user_one)
c2 = criterion("user_one_membership", group_a in m1 and group_b in m1, 2, "first user belongs to both groups", ",".join(m1) or "user missing")
m2 = supplementary(user_two)
c3 = criterion("user_two_membership", group_a in m2, 2, "second user belongs to the first group", ",".join(m2) or "user missing")
c4 = criterion("user_one_primary", primary_group(user_one) == user_one, 2, "first user's primary group is unchanged", primary_group(user_one) or "unavailable")
c5 = criterion("user_two_primary", primary_group(user_two) == user_two, 2, "second user's primary group is unchanged", primary_group(user_two) or "unavailable")
criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
