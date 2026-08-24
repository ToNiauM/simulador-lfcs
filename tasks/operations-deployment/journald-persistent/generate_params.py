#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "dropin_file": f"/etc/systemd/journald.conf.d/60-lfcs-{token}.conf",
}, sort_keys=True))
