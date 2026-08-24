#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "module": "dummy",
    "numdummies": 2 + int(digest[6:8], 16) % 4,
    "load_file": f"/etc/modules-load.d/lfcs-{token}.conf",
    "options_file": f"/etc/modprobe.d/lfcs-{token}.conf",
}, sort_keys=True))
