#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
print(json.dumps({
    "tcp_port": 20000 + int(digest[6:10], 16) % 20000,
}, sort_keys=True))
