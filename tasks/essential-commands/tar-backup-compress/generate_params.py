#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
globs = ("*.tmp", "*.bak", "*.cache")
print(json.dumps({
    "data_dir": f"/srv/dados-{token}",
    "archive_path": f"/root/backup-{token}.tar.gz",
    "exclude_glob": globs[int(digest[6:8], 16) % len(globs)],
    "script_mode": "750",
    "fixture_token": digest[8:16],
}, sort_keys=True))
