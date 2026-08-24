#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]

statuses = ["ok", "warn", "retry", "done", "skip"]
gzip_lines = []
for i in range(20):
    h = int(digest[(2 * i) % 56:(2 * i) % 56 + 4], 16)
    gzip_lines.append(f"{token} service entry {i:02d} status {statuses[h % len(statuses)]} code {h % 500}")
xz_lines = []
for i in range(16):
    h = int(digest[(3 * i) % 56:(3 * i) % 56 + 4], 16)
    xz_lines.append(f"{token} audit event {i:02d} actor u{h % 90:02d} action {statuses[(h >> 4) % len(statuses)]}")

print(json.dumps({
    "work_dir": f"/srv/arquivos-{token}",
    "gzip_file": f"diario-{token}.log",
    "xz_file": f"auditoria-{token}.log",
    "gzip_content": "\n".join(gzip_lines),
    "xz_content": "\n".join(xz_lines),
}, sort_keys=True))
