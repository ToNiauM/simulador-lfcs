#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "acl_user": f"aud{digest[6:10]}",
    "data_dir": f"/srv/registros-{token}",
    "dir_base_mode": "750",
    "file_a": "relatorio-a.txt",
    "file_b": "relatorio-b.txt",
    "fixture_token": digest[10:18],
}, sort_keys=True))
