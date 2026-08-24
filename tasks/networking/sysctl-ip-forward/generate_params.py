#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
number = 60 + int(digest[6:8], 16) % 30
print(json.dumps({
    "sysctl_file": f"/etc/sysctl.d/{number}-lfcs-{token}.conf",
}, sort_keys=True))
