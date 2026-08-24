#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
initial_sizes = (320, 352)
initial = initial_sizes[int(digest[12:14], 16) % len(initial_sizes)]
print(json.dumps({
    "target_disk": "/dev/vdb",
    "filesystem": "xfs",
    "vg_name": f"vgx{token}",
    "lv_name": f"lvx{digest[6:12]}",
    "initial_size_mib": initial,
    "target_size_mib": initial + 256,
    "mount_point": f"/srv/xfs-{digest[14:20]}",
}, sort_keys=True))
