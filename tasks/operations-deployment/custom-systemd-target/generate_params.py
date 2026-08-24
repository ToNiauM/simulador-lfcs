#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
print(json.dumps({
    "target_name": f"lab-{digest[:6]}.target",
    "service_a": f"app-{digest[6:11]}.service",
    "service_b": f"worker-{digest[11:16]}.service",
}, sort_keys=True))
