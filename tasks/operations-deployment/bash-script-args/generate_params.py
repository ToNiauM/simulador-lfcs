#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
argc_choices = (2, 3)
exit_choices = (2, 3, 4, 5)
print(json.dumps({
    "script_path": f"/usr/local/bin/argtool-{token}",
    "expected_argc": argc_choices[int(digest[6:8], 16) % len(argc_choices)],
    "error_exit_code": exit_choices[int(digest[8:10], 16) % len(exit_choices)],
}, sort_keys=True))
