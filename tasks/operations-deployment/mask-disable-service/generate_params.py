#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
print(json.dumps({
    "service_mask": f"batch-{digest[:5]}.service",
    "service_disable": f"report-{digest[5:10]}.service",
}, sort_keys=True))
