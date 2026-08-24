#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
bases = ("auditor", "vendor", "extops", "suporte")
commands = ("/usr/bin/uptime", "/usr/bin/id", "/bin/date", "/usr/bin/who")
print(json.dumps({
    "restricted_user": bases[int(digest[12:14], 16) % len(bases)] + digest[:3],
    "forced_command": commands[int(digest[14:16], 16) % len(commands)],
}, sort_keys=True))
