#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "interface": "enp0s5",
    "search_domain_1": f"lab{token}.example",
    "search_domain_2": f"corp{digest[6:11]}.example",
}, sort_keys=True))
