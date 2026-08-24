#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
soft_choices = (4096, 8192, 10240)
hard_choices = (16384, 32768, 65536)
print(json.dumps({
    "username": f"lim{digest[:5]}",
    "limits_file": f"/etc/security/limits.d/90-lfcs-{digest[5:10]}.conf",
    "soft_nofile": soft_choices[int(digest[10:12], 16) % len(soft_choices)],
    "hard_nofile": hard_choices[int(digest[12:14], 16) % len(hard_choices)],
}, sort_keys=True))
