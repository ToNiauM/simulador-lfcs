#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
sizes = (96, 128, 160)
print(json.dumps({
    "target_disk": "/dev/vdb",
    "vg_name": f"vg{token}",
    "lv_name": f"lv{digest[6:12]}",
    "lv_size_mib": sizes[int(digest[12:14], 16) % len(sizes)],
    "filesystem": "ext4",
    "mount_point": f"/srv/lfcs-{token}",
}, sort_keys=True))
