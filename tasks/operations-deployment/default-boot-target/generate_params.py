#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
# Targets are fixed by the task definition; the digest keeps the
# derivation deterministic and available for future variation.
_ = digest
print(json.dumps({
    "expected_target": "multi-user.target",
    "initial_target": "graphical.target",
}, sort_keys=True))
