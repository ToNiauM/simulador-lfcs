#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
print(json.dumps({
    "group_a": f"team{digest[:4]}",
    "group_b": f"proj{digest[4:8]}",
    "user_one": f"ana{digest[8:12]}",
    "user_two": f"bob{digest[12:16]}",
}, sort_keys=True))
