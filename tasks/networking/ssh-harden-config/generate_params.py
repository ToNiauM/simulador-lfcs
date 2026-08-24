#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
options = ("prohibit-password", "no")
print(json.dumps({
    "permit_root_login": options[int(digest[6:8], 16) % len(options)],
    "match_user": f"deploy{token}",
}, sort_keys=True))
