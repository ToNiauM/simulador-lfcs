#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
somaxconn_options = (1024, 2048, 4096)
fin_timeout_options = (15, 20, 25, 30)
print(json.dumps({
    "tcp_syncookies": 1,
    "somaxconn": somaxconn_options[int(digest[0:2], 16) % len(somaxconn_options)],
    "tcp_fin_timeout": fin_timeout_options[int(digest[2:4], 16) % len(fin_timeout_options)],
}, sort_keys=True))
