#!/usr/bin/env bash
set -euo pipefail

[[ -n "${LFCS_PARAMS_FILE:-}" && -r "$LFCS_PARAMS_FILE" ]] || { echo '{"schema_version":1,"task_id":"essential-commands/git-init-first-commit","result":"error","score":0,"max_score":8,"criteria":[{"id":"parameters","result":"error","points":0,"max_points":8,"message":"missing parameters","evidence":"LFCS_PARAMS_FILE unavailable"}]}' ; exit 0; }

python3 - "$LFCS_PARAMS_FILE" <<'PY'
import json, os, subprocess, sys

payload = json.load(open(sys.argv[1]))
p = payload["params"]

def criterion(identifier, ok, points, message, evidence):
    return {"id": identifier, "result": "pass" if ok else "fail", "points": points if ok else 0, "max_points": points, "message": message, "evidence": evidence[:240]}

def run(*args):
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.returncode, proc.stdout

repo = p["repo_dir"]
config_file = os.path.join(repo, ".git", "config")

rc_head, head = run("git", "-C", repo, "rev-parse", "--verify", "HEAD")
repo_ok = os.path.isdir(os.path.join(repo, ".git")) and rc_head == 0
c1 = criterion("repo_with_commit", repo_ok, 2,
               "directory is a Git repository with at least one commit",
               head.strip() if repo_ok else "no repository or no commit found")

_, cfg_name = run("git", "config", "--file", config_file, "--get", "user.name")
_, cfg_email = run("git", "config", "--file", config_file, "--get", "user.email")
config_ok = cfg_name.strip() == p["author_name"] and cfg_email.strip() == p["author_email"]
c2 = criterion("local_identity", config_ok, 2,
               "repository-local user.name and user.email are configured as requested",
               f"user.name={cfg_name.strip() or '-'} user.email={cfg_email.strip() or '-'}")

_, message = run("git", "-C", repo, "log", "-1", "--format=%B")
_, author = run("git", "-C", repo, "log", "-1", "--format=%an <%ae>")
message_ok = repo_ok and message.strip() == p["commit_message"]
author_ok = repo_ok and author.strip() == f"{p['author_name']} <{p['author_email']}>"
c3 = criterion("commit_message_author", message_ok and author_ok, 2,
               "first commit has the exact requested message and author identity",
               f"message={message.strip() or '-'}; author={author.strip() or '-'}")

files_ok = False
evidence = "commit missing"
if repo_ok:
    rc1, shown1 = run("git", "-C", repo, "show", f"HEAD:{p['file1_name']}")
    rc2, shown2 = run("git", "-C", repo, "show", f"HEAD:{p['file2_name']}")
    files_ok = rc1 == 0 and rc2 == 0 \
        and shown1.strip() == p["file1_content"].strip() \
        and shown2.strip() == p["file2_content"].strip()
    evidence = "both project files committed with original content" if files_ok else "a project file is missing from the commit or was modified"
c4 = criterion("files_committed", files_ok, 2,
               "the commit contains both project files with their original content", evidence)

criteria = [c1, c2, c3, c4]
score = sum(item["points"] for item in criteria)
print(json.dumps({"schema_version": 1, "task_id": payload["task_id"], "result": "pass" if score == 8 else "fail", "score": score, "max_score": 8, "criteria": criteria}, separators=(",", ":")))
PY
