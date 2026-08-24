#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]

prefixes = ["relatorio", "exportacao", "captura", "medida"]
ext_pairs = [("txt", "log"), ("dat", "csv"), ("tmp", "bak")]
prefix = prefixes[int(digest[6:8], 16) % len(prefixes)]
old_ext, new_ext = ext_pairs[int(digest[8:10], 16) % len(ext_pairs)]

print(json.dumps({
    "work_dir": f"/srv/lote-{token}",
    "prefix": prefix,
    "old_ext": old_ext,
    "new_ext": new_ext,
    "count": 5 + int(digest[10:12], 16) % 4,
    "lot_id": token,
    "keep_file": f"{prefix}-resumo.md",
}, sort_keys=True))
