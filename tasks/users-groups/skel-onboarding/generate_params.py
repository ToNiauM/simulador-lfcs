#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
print(json.dumps({
    "skel_file": f"welcome-{digest[:5]}.txt",
    "skel_content": f"Onboarding checklist id {digest[5:13]}",
    "username": f"onb{digest[13:18]}",
}, sort_keys=True))
