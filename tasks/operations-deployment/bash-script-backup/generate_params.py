#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "script_path": f"/usr/local/bin/backup-{token}",
    "archive_prefix": f"bkp{digest[6:10]}",
    "source_dir": f"/opt/lfcs-data-{token}",
    "data_token": digest[10:26],
}, sort_keys=True))
