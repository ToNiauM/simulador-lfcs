#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
host = 1 + int(digest[8:10], 16) % 250
print(json.dumps({
    "bridge_name": f"br-{token}",
    "dummy_if": f"dm{digest[6:10]}",
    "bridge_ip": f"192.0.2.{host}/24",
}, sort_keys=True))
