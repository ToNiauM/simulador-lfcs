#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
thresholds = (64, 128, 256)
print(json.dumps({
    "base_dir": f"/srv/lfcs-scan-{token}",
    "report_file": f"/root/relatorio-{token}.txt",
    "threshold_kib": thresholds[int(digest[6:8], 16) % len(thresholds)],
    "age_days": 30,
    "fixture_token": digest[8:16],
}, sort_keys=True))
