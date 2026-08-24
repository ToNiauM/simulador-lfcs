#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
username = f"svc{digest[:5]}"
print(json.dumps({
    "username": username,
    "uid": 300 + int(digest[5:8], 16) % 600,
    "home_dir": f"/var/lib/{username}",
}, sort_keys=True))
