#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "archive_path": f"/root/release-{token}.tar.gz",
    "dest_dir": f"/opt/deploy-{token}",
    "app_name": f"app-{token}",
    "wanted_subdir": "conf",
    "fixture_token": digest[6:14],
}, sort_keys=True))
