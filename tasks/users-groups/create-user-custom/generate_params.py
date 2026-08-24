#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
username = f"dev{digest[:5]}"
shells = ("/bin/bash", "/bin/sh", "/bin/dash")
print(json.dumps({
    "username": username,
    "uid": 2000 + int(digest[5:8], 16) % 800,
    "home_dir": f"/home/lab-{digest[8:13]}",
    "shell": shells[int(digest[13:15], 16) % len(shells)],
    "comment": f"LFCS lab account {digest[15:21]}",
}, sort_keys=True))
