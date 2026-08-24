#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
pool_sizes = (192, 256)
virtual_sizes = (384, 512, 640)
print(json.dumps({
    "target_disk": "/dev/vdb",
    "vg_name": f"vg{token}",
    "pool_name": f"pool{digest[6:10]}",
    "thin_lv_name": f"thin{digest[10:14]}",
    "pool_size_mib": pool_sizes[int(digest[14:16], 16) % len(pool_sizes)],
    "thin_virtual_size_mib": virtual_sizes[int(digest[16:18], 16) % len(virtual_sizes)],
}, sort_keys=True))
