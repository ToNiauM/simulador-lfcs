#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/git-branch-merge","result":"error","score":0,"max_score":10,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":10,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.returncode, proc.stdout

repo = p["repo_dir"]
main = p["main_branch"]
feature = p["feature_branch"]

rc_branch, branch_tip = run("git", "-C", repo, "rev-parse", "--verify", f"refs/heads/{feature}")
c1 = criterion("feature_branch_exists", rc_branch == 0, 2,
               "the feature branch exists",
               branch_tip.strip() if rc_branch == 0 else f"branch {feature} not found")

rc_log, subjects = run("git", "-C", repo, "log", "--format=%s", main)
message_ok = rc_log == 0 and p["feature_commit_message"] in subjects.splitlines()
c2 = criterion("feature_commit_message", message_ok, 2,
               "a commit with the exact requested message is reachable from the main branch",
               "commit message found on main history" if message_ok else "requested commit message not reachable from main")

rc_show, shown = run("git", "-C", repo, "show", f"{main}:{p['feature_file']}")
content_ok = rc_show == 0 and shown.strip() == p["feature_content"].strip()
c3 = criterion("file_on_main", content_ok, 2,
               "the main branch contains the new file with the exact requested content",
               "file present with expected content" if content_ok else ("file missing on main" if rc_show != 0 else "file content differs"))

rc_anc, _ = run("git", "-C", repo, "merge-base", "--is-ancestor", feature, main)
merged_ok = rc_branch == 0 and rc_anc == 0
c4 = criterion("branch_merged", merged_ok, 2,
               "the feature branch has been merged into the main branch",
               "feature tip is an ancestor of main" if merged_ok else "feature branch is not merged into main")

rc_head, current = run("git", "-C", repo, "symbolic-ref", "--short", "HEAD")
head_ok = rc_head == 0 and current.strip() == main
c5 = criterion("main_checked_out", head_ok, 2,
               "the main branch is the currently checked-out branch",
               current.strip() if current.strip() else "detached HEAD or no repository")

criteria = [c1, c2, c3, c4, c5]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 10 else "fail", "score": score, "max_score": 10, "criteria": criteria}, separators=(",", ":")))
PY
