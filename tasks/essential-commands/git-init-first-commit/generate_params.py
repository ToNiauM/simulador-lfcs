#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]

first_names = ["Ana", "Bruno", "Carla", "Diego", "Elisa", "Fabio"]
last_names = ["Souza", "Lima", "Costa", "Pires", "Rocha", "Neves"]
author_name = f"{first_names[int(digest[6:8], 16) % len(first_names)]} {last_names[int(digest[8:10], 16) % len(last_names)]}"

file1_content = "\n".join([
    f"# Projeto {token}",
    "",
    f"Lab repository {digest[10:18]}.",
])
file2_content = "\n".join([
    f"release={digest[18:24]}",
    f"build={int(digest[24:26], 16)}",
    "channel=stable",
])

print(json.dumps({
    "repo_dir": f"/srv/projeto-{token}",
    "author_name": author_name,
    "author_email": f"dev{token}@example.com",
    "commit_message": f"Initial import of project {token}",
    "file1_name": "README.md",
    "file1_content": file1_content,
    "file2_name": f"config-{digest[26:30]}.ini",
    "file2_content": file2_content,
}, sort_keys=True))
