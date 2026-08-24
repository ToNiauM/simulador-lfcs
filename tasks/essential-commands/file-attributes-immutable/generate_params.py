#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]

immutable_content = "\n".join([
    f"instance={token}",
    f"revision={digest[6:14]}",
    "locked=true",
])
append_content = "\n".join([
    f"{token} journal opened",
    f"first entry {digest[14:22]}",
])

print(json.dumps({
    "work_dir": f"/srv/protegido-{token}",
    "immutable_file": f"config-{digest[22:26]}.conf",
    "append_file": f"registro-{digest[26:30]}.log",
    "immutable_content": immutable_content,
    "append_content": append_content,
}, sort_keys=True))
