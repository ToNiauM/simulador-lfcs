#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]

feature_content = "\n".join([
    f"module {token}",
    f"revision {digest[6:14]}",
    f"checksum {digest[14:22]}",
])
base_content = "\n".join([
    f"# Codigo {token}",
    "",
    "Base file created by the lab environment.",
])

print(json.dumps({
    "repo_dir": f"/srv/codigo-{token}",
    "main_branch": "main",
    "feature_branch": f"feature-{digest[6:10]}",
    "feature_file": f"modulo-{digest[10:14]}.txt",
    "feature_content": feature_content,
    "feature_commit_message": f"Add module {digest[10:14]}",
    "base_file": "README.md",
    "base_content": base_content,
}, sort_keys=True))
