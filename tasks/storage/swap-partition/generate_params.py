#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
sizes = (128, 192, 256)
print(json.dumps({
    "target_disk": "/dev/vdb",
    "swap_size_mib": sizes[int(digest[0:2], 16) % len(sizes)],
    "swap_priority": 5 + int(digest[4:6], 16) % 16,
}, sort_keys=True))
