#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
origin_sizes = (160, 200)
snap_sizes = (32, 48, 64)
print(json.dumps({
    "target_disk": "/dev/vdb",
    "vg_name": f"vg{token}",
    "origin_lv": f"data{digest[6:10]}",
    "snap_name": f"snap{digest[10:14]}",
    "origin_size_mib": origin_sizes[int(digest[14:16], 16) % len(origin_sizes)],
    "snap_size_mib": snap_sizes[int(digest[16:18], 16) % len(snap_sizes)],
}, sort_keys=True))
