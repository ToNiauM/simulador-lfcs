#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "facility": f"local{2 + int(digest[6:8], 16) % 5}",
    "conf_file": f"/etc/rsyslog.d/55-{token}.conf",
    "log_file": f"/var/log/lab-{token}.log",
    "test_token": f"LFCS-{digest[8:16]}",
}, sort_keys=True))
