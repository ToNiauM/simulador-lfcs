#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "ntp_server_1": f"ntp1.lab-{token}.example",
    "ntp_server_2": f"ntp2.lab-{token}.example",
    "fallback_server": f"ntp0.lab-{token}.example",
}, sort_keys=True))
