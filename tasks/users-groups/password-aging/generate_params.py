#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
max_choices = (60, 75, 90)
min_choices = (5, 7, 10)
warn_choices = (9, 12, 14)
print(json.dumps({
    "username": f"aud{digest[:5]}",
    "max_days": max_choices[int(digest[5:7], 16) % len(max_choices)],
    "min_days": min_choices[int(digest[7:9], 16) % len(min_choices)],
    "warn_days": warn_choices[int(digest[9:11], 16) % len(warn_choices)],
}, sort_keys=True))
