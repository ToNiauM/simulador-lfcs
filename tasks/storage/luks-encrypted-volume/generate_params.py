#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "target_disk": "/dev/vdb",
    "filesystem": "ext4",
    "part_size_mib": 256,
    "mapper_name": f"luks{token}",
    "key_file": f"/root/luks-{digest[6:12]}.key",
    "mount_point": f"/srv/secure-{digest[12:18]}",
}, sort_keys=True))
