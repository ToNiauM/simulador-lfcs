#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "tree_dir": f"/srv/projeto-{token}",
    "owner_user": f"svc{digest[6:10]}",
    "owner_group": f"equipe{digest[10:14]}",
    "fixture_token": digest[14:22],
}, sort_keys=True))
