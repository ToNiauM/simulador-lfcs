#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
p1_sizes = (100, 128, 160)
p2_sizes = (192, 224, 256)
print(json.dumps({
    "target_disk": "/dev/vdb",
    "part1_size_mib": p1_sizes[int(digest[0:2], 16) % len(p1_sizes)],
    "part2_size_mib": p2_sizes[int(digest[2:4], 16) % len(p2_sizes)],
}, sort_keys=True))
