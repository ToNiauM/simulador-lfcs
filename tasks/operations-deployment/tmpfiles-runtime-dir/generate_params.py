#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
modes = ("0750", "0770", "0700")
owner = f"svc-{digest[6:11]}"
print(json.dumps({
    "runtime_dir": f"/run/app-{token}",
    "dir_owner": owner,
    "dir_group": owner,
    "dir_mode": modes[int(digest[11:13], 16) % len(modes)],
}, sort_keys=True))
