#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
print(json.dumps({
    "group_name": f"colab{digest[:4]}",
    "user_one": f"eva{digest[4:8]}",
    "user_two": f"ivo{digest[8:12]}",
    "shared_dir": f"/srv/colab-{digest[12:17]}",
}, sort_keys=True))
