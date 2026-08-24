#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
group1 = format(int(digest[0:4], 16), "x")
group2 = format(int(digest[4:8], 16), "x")
host = 1 + int(digest[8:10], 16) % 200
print(json.dumps({
    "nic": "enp0s5",
    "ipv6_address": f"2001:db8:{group1}:{group2}::{host:x}/64",
}, sort_keys=True))
