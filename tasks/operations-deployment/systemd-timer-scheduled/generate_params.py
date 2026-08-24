#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
hour = int(digest[6:8], 16) % 24
minute = int(digest[8:10], 16) % 60
print(json.dumps({
    "timer_name": f"maint-{token}",
    "script_path": f"/opt/lfcs-{token}/maintenance.sh",
    "on_calendar": f"*-*-* {hour:02d}:{minute:02d}:00",
}, sort_keys=True))
