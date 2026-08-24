#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
octet = 10 + int(digest[0:2], 16) % 240
print(json.dumps({
    "loopback_address": f"192.0.2.{octet}/32",
}, sort_keys=True))
