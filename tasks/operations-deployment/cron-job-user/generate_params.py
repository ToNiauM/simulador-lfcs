#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "username": f"cron{digest[6:11]}",
    "script_path": f"/opt/lfcs-{token}/report.sh",
    "minute": int(digest[11:13], 16) % 60,
    "hour": int(digest[13:15], 16) % 24,
}, sort_keys=True))
