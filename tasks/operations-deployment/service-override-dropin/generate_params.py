#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "service_name": f"sync-{token}",
    "script_path": f"/opt/lfcs-{token}/agent.sh",
    "restart_policy": "always",
    "env_name": "SYNC_MODE",
    "env_value": f"maintenance-{digest[6:10]}",
}, sort_keys=True))
