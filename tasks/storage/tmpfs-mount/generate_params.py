#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
sizes = (64, 96, 128)
modes = ("1777", "0770", "0750")
print(json.dumps({
    "mount_point": f"/mnt/scratch-{token}",
    "size_mib": sizes[int(digest[6:8], 16) % len(sizes)],
    "mode": modes[int(digest[8:10], 16) % len(modes)],
}, sort_keys=True))
