#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]

def pick(offset, options):
    return options[int(digest[offset:offset + 2], 16) % len(options)]

delimiter = pick(6, [";", ",", ":"])
fields = pick(8, ["1,3", "2,4", "1,4", "2,3"])
names = ["ana", "bruno", "carla", "diego", "elisa", "fabio", "gilda", "hugo", "iris", "jonas"]
cities = ["recife", "porto", "lisboa", "manaus", "cuiaba", "aveiro", "braga", "natal"]
rows = [delimiter.join(["id", "nome", "cidade", "valor"])]
count = 8 + int(digest[10:12], 16) % 4
for i in range(count):
    h = int(digest[12 + 2 * i:16 + 2 * i], 16)
    rows.append(delimiter.join([
        str(100 + i),
        names[h % len(names)],
        cities[(h >> 3) % len(cities)],
        str(10 + h % 90),
    ]))
print(json.dumps({
    "work_dir": f"/srv/relatorios-{token}",
    "source_file": f"vendas-{token}.csv",
    "output_file": f"campos-{digest[6:10]}.txt",
    "delimiter": delimiter,
    "fields": fields,
    "csv_content": "\n".join(rows),
}, sort_keys=True))
