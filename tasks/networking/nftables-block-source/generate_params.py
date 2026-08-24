#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
networks = ("192.0.2", "198.51.100", "203.0.113")
network = networks[int(digest[6:8], 16) % len(networks)]
print(json.dumps({
    "blocked_subnet": f"{network}.0/24",
}, sort_keys=True))
