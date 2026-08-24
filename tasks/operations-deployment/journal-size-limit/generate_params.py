#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
max_use_options = ("96M", "128M", "192M", "256M")
retention_options = ("3day", "5day", "1week", "2week")
print(json.dumps({
    "dropin_file": f"/etc/systemd/journald.conf.d/60-{token}-limits.conf",
    "system_max_use": max_use_options[int(digest[6:8], 16) % len(max_use_options)],
    "max_retention_sec": retention_options[int(digest[8:10], 16) % len(retention_options)],
}, sort_keys=True))
