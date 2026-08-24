#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
print(json.dumps({
    "banner_file": "/etc/issue.net",
    "banner_text": f"AUTHORIZED ACCESS ONLY - REF {digest[:8].upper()}",
    "motd_text": f"Managed system - change ref {digest[8:16]}",
}, sort_keys=True))
