#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "backend_service": f"lfcs-backend-{token}",
    "backend_dir": f"/srv/lfcs-backend-{token}",
    "backend_port": 9901 + int(digest[10:14], 16) % 2000,
    "public_port": 8081 + int(digest[6:10], 16) % 1800,
    "content_token": digest[20:32],
}, sort_keys=True))
