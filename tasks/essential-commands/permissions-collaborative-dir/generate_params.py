#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "group_name": f"proj{token}",
    "share_dir": f"/srv/share-{token}",
    "user_a": f"ana{digest[6:10]}",
    "user_b": f"bruno{digest[10:14]}",
    "dir_mode": "2770",
}, sort_keys=True))
