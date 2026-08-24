#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "nft_table": f"lfcs{token}",
    "src_port": 10000 + int(digest[6:10], 16) % 5000,
    "dst_port": 15000 + int(digest[10:14], 16) % 5000,
}, sort_keys=True))
