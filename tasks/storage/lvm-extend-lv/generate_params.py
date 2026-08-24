#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
initial_sizes = (96, 128)
target_sizes = (256, 320, 384)
print(json.dumps({
    "target_disk": "/dev/vdb",
    "filesystem": "ext4",
    "vg_name": f"vg{token}",
    "lv_name": f"lv{digest[6:12]}",
    "initial_size_mib": initial_sizes[int(digest[12:14], 16) % len(initial_sizes)],
    "target_size_mib": target_sizes[int(digest[14:16], 16) % len(target_sizes)],
    "mount_point": f"/srv/lfcs-{token}",
}, sort_keys=True))
