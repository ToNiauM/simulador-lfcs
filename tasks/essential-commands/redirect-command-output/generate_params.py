#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]

stdout_lines = [f"collect {i:02d} ok sample {digest[2 * i:2 * i + 6]}" for i in range(1, 6)]
stderr_lines = [f"failure {i:02d} device d{int(digest[30 + 2 * i:32 + 2 * i], 16) % 90:02d} unreachable" for i in range(1, 4)]

print(json.dumps({
    "program_path": f"/usr/local/bin/coletor-{token}",
    "output_dir": f"/srv/saidas-{token}",
    "stdout_file": f"saida-{digest[6:10]}.txt",
    "stderr_file": f"erros-{digest[10:14]}.txt",
    "stdout_content": "\n".join(stdout_lines),
    "stderr_content": "\n".join(stderr_lines),
}, sort_keys=True))
