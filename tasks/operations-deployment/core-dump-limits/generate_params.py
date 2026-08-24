#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
choices = (("fs.suid_dumpable", "0"), ("kernel.core_pattern", "/dev/null"))
key, value = choices[int(digest[6:8], 16) % len(choices)]
print(json.dumps({
    "limits_file": f"/etc/security/limits.d/60-{token}-core.conf",
    "sysctl_file": f"/etc/sysctl.d/60-{token}-core.conf",
    "sysctl_key": key,
    "sysctl_value": value,
}, sort_keys=True))
