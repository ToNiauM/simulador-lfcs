#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()

print(json.dumps({
    "key_user": f"dev{digest[0:4]}",
    "target_user": f"deploy{digest[4:8]}",
    "key_type": "ed25519",
}, sort_keys=True))
