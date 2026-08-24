#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
nice_choices = (5, 10, 12, 15)
io_choices = ("best-effort", "idle")
print(json.dumps({
    "service_name": f"batch-{token}",
    "worker_script": f"/usr/local/lib/lfcs/batch-{token}.sh",
    "nice_value": nice_choices[int(digest[6:8], 16) % len(nice_choices)],
    "io_class": io_choices[int(digest[8:10], 16) % len(io_choices)],
}, sort_keys=True))
