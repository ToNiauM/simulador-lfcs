#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
limits = (20480, 30720, 40960, 51200)
print(json.dumps({
    "target_disk": "/dev/vdb",
    "filesystem": "ext4",
    "part_size_mib": 300,
    "username": f"qu{digest[6:12]}",
    "block_hard_kib": limits[int(digest[12:14], 16) % len(limits)],
    "mount_point": f"/srv/projects-{token}",
}, sort_keys=True))
