#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "service_name": f"batch-{token}",
    "script_path": f"/opt/lfcs-{token}/worker.sh",
}, sort_keys=True))
