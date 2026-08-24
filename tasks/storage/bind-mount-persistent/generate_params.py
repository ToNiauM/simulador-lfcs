#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "source_dir": f"/srv/lfcs-data-{token}",
    "bind_target": f"/mnt/lfcs-mirror-{digest[6:12]}",
    "sentinel_file": "dados.txt",
    "sentinel_content": digest[12:28],
}, sort_keys=True))
