#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
print(json.dumps({
    "data_file": f"/srv/lfcs-{token}/acessos.txt",
    "report_file": f"/root/contagem-{token}.txt",
    "fixture_token": digest[6:14],
}, sort_keys=True))
