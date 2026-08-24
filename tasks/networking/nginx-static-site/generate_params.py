#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "content_dir": f"/srv/www/site-{token}",
    "http_port": 8081 + int(digest[6:10], 16) % 1800,
    "content_token": digest[16:28],
}, sort_keys=True))
