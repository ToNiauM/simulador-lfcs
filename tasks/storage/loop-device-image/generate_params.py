#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
sizes = (64, 96, 128)
print(json.dumps({
    "image_path": f"/var/lib/lfcs-disk-{token}.img",
    "size_mib": sizes[int(digest[6:8], 16) % len(sizes)],
    "filesystem": "ext4",
    "mount_point": f"/srv/loopfs-{digest[8:14]}",
}, sort_keys=True))
