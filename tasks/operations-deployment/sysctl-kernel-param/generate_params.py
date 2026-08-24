#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "conf_file": f"/etc/sysctl.d/60-lfcs-{token}.conf",
    "swappiness": 10 + int(digest[6:8], 16) % 41,
    "pid_max": 131072 + (int(digest[8:10], 16) % 64) * 1024,
}, sort_keys=True))
