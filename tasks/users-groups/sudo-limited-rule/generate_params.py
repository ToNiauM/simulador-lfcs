#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
commands = ("/usr/bin/df", "/usr/bin/du", "/usr/bin/free", "/usr/bin/uptime")
print(json.dumps({
    "username": f"ops{digest[:5]}",
    "allowed_command": commands[int(digest[5:7], 16) % len(commands)],
    "sudoers_file": f"/etc/sudoers.d/lfcs-{digest[7:12]}",
}, sort_keys=True))
