#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
sizes = (150, 200, 250)
print(json.dumps({
    "target_disk": "/dev/vdb",
    "filesystem": "ext4",
    "part_size_mib": sizes[int(digest[8:10], 16) % len(sizes)],
    "fs_label": f"DATA{token.upper()}",
    "mount_point": f"/srv/label-{token}",
}, sort_keys=True))
