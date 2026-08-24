#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
mtus = (1280, 1300, 1350, 1400, 1420, 1450)
print(json.dumps({
    "nic": "enp0s5",
    "mtu": mtus[int(digest[6:8], 16) % len(mtus)],
}, sort_keys=True))
