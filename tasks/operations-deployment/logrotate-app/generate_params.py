#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
app = f"app{digest[:5]}"
modes = ("0600", "0640", "0644")
groups = ("root", "adm")
print(json.dumps({
    "app_name": app,
    "log_path": f"/var/log/{app}/{app}.log",
    "rotate_count": 4 + int(digest[5:7], 16) % 6,
    "create_mode": modes[int(digest[7:9], 16) % len(modes)],
    "create_user": "root",
    "create_group": groups[int(digest[9:11], 16) % len(groups)],
}, sort_keys=True))
