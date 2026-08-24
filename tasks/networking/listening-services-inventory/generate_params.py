#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "report_path": f"/root/listening-ports-{token}.txt",
    "svc_a": f"lfcs-listen-a-{token}",
    "svc_b": f"lfcs-listen-b-{token}",
    "port_a": 20000 + int(digest[6:10], 16) % 2000,
    "port_b": 22001 + int(digest[10:14], 16) % 1999,
}, sort_keys=True))
