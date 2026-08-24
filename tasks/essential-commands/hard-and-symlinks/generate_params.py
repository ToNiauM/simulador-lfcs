#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
work_dir = f"/srv/links-{token}"
print(json.dumps({
    "work_dir": work_dir,
    "hard_target": f"{work_dir}/data/origin-{digest[6:10]}.dat",
    "hard_link": f"{work_dir}/backup/copy-{digest[6:10]}.dat",
    "sym_target": f"{work_dir}/releases/build-{digest[10:14]}.txt",
    "sym_link": f"{work_dir}/current",
    "fixture_token": digest[14:22],
}, sort_keys=True))
