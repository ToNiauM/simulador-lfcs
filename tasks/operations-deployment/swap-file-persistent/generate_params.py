#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
sizes = (256, 384, 512)
swappiness_values = (15, 25, 35, 45)
print(json.dumps({
    "swap_file": f"/swap-lfcs-{token}.img",
    "swap_size_mib": sizes[int(digest[6:8], 16) % len(sizes)],
    "swappiness": swappiness_values[int(digest[8:10], 16) % len(swappiness_values)],
}, sort_keys=True))
