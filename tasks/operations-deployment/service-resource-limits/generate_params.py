#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
memory_choices = (128, 192, 256)
cpu_choices = (20, 40, 50, 80)
tasks_choices = (16, 32, 64)
print(json.dumps({
    "service_name": f"worker-{token}",
    "memory_max_mib": memory_choices[int(digest[6:8], 16) % len(memory_choices)],
    "cpu_quota_pct": cpu_choices[int(digest[8:10], 16) % len(cpu_choices)],
    "tasks_max": tasks_choices[int(digest[10:12], 16) % len(tasks_choices)],
}, sort_keys=True))
