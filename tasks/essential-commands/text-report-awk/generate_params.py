#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]

pool = ["cpu", "memoria", "disco", "rede", "carga", "tempo"]
start = int(digest[6:8], 16) % len(pool)
categories = [pool[(start + i) % len(pool)] for i in range(3)]

# Four integer samples per category so every mean is an exact multiple of 0.25.
values = {}
for c_index, category in enumerate(categories):
    values[category] = [
        10 + int(digest[8 + 2 * (4 * c_index + k):10 + 2 * (4 * c_index + k)], 16) % 90
        for k in range(4)
    ]
lines = []
for round_index in range(4):
    for category in categories:
        lines.append(f"{category} {values[category][round_index]}")

print(json.dumps({
    "work_dir": f"/srv/metricas-{token}",
    "data_file": f"consumo-{token}.dat",
    "report_file": f"resumo-{digest[6:10]}.txt",
    "data_content": "\n".join(lines),
}, sort_keys=True))
