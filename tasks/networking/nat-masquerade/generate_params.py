#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
octet_a = int(digest[0:2], 16)
octet_b = int(digest[2:4], 16)
print(json.dumps({
    "lan_subnet": f"10.{octet_a}.{octet_b}.0/24",
    "wan_interface": "enp0s5",
}, sort_keys=True))
