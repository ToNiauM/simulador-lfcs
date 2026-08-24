#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
days = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
minutes = (0, 15, 30, 45)
day = days[int(digest[0:2], 16) % len(days)]
hour = int(digest[2:4], 16) % 6
minute = minutes[int(digest[4:6], 16) % len(minutes)]
print(json.dumps({
    "trim_day": day,
    "trim_time": f"{hour:02d}:{minute:02d}",
}, sort_keys=True))
