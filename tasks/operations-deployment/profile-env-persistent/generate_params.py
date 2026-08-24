#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "var_name": f"LFCS_APP_{digest[6:10].upper()}",
    "var_value": f"lab-{digest[10:18]}",
    "script_path": f"/etc/profile.d/lfcs-{token}.sh",
}, sort_keys=True))
