#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
month = 1 + int(digest[5:7], 16) % 12
day = 1 + int(digest[7:9], 16) % 28
print(json.dumps({
    "username": f"lex{digest[:5]}",
    "expire_date": f"2027-{month:02d}-{day:02d}",
}, sort_keys=True))
