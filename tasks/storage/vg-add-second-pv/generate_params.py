#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
sizes = (256, 300, 350)
print(json.dumps({
    "target_disk": "/dev/vdb",
    "vg_name": f"vg{token}",
    "part_size_mib": sizes[int(digest[6:8], 16) % len(sizes)],
}, sort_keys=True))
