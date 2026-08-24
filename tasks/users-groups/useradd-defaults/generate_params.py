#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
shells = ("/bin/bash", "/bin/dash", "/bin/rbash")
print(json.dumps({
    "default_shell": shells[int(digest[:2], 16) % len(shells)],
    "base_dir": f"/srv/homes-{digest[2:7]}",
    "username": f"prv{digest[7:12]}",
}, sort_keys=True))
