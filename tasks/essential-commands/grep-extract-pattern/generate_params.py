#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
levels = ("ERROR", "WARN", "CRIT")
print(json.dumps({
    "log_file": f"/var/log/app-{token}.log",
    "out_file": f"/root/filtrado-{token}.txt",
    "level": levels[int(digest[6:8], 16) % len(levels)],
    "fixture_token": digest[8:16],
}, sort_keys=True))
