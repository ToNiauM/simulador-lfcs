#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
levels = ("warning", "error", "notice")
old_port = 8000 + int(digest[8:11], 16) % 1000
new_port = 20000 + int(digest[11:14], 16) % 10000
print(json.dumps({
    "conf_file": f"/etc/appd-{token}.conf",
    "old_port": old_port,
    "new_port": new_port,
    "old_log_level": "debug",
    "new_log_level": levels[int(digest[6:8], 16) % len(levels)],
    "listen_addr": f"192.0.2.{1 + int(digest[14:16], 16) % 200}",
    "max_clients": 50 + int(digest[16:18], 16) % 200,
    "workers": 2 + int(digest[18:20], 16) % 7,
    "data_dir": f"/var/lib/appd-{token}",
}, sort_keys=True))
