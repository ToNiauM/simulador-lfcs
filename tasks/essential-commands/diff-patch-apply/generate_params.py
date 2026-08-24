#!/usr/bin/env python3
import difflib
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]

port = 1024 + int(digest[6:10], 16) % 30000
limit = 10 + int(digest[10:12], 16) % 90
new_limit = limit + 5
conf_name = f"config-{digest[12:16]}.ini"
notes_name = f"notas-{digest[16:20]}.txt"

conf_old = [
    f"porta={port}\n",
    "modo=producao\n",
    f"limite={limit}\n",
    "debug=nao\n",
]
conf_new = [
    f"porta={port}\n",
    "modo=producao\n",
    f"limite={new_limit}\n",
    "debug=sim\n",
]
notes_old = [
    f"nota 1: instancia {token}\n",
    f"nota 2: revisao {digest[20:28]}\n",
    "nota 3: pendente\n",
]
notes_new = [
    f"nota 1: instancia {token}\n",
    f"nota 2: revisao {digest[20:28]}\n",
    "nota 3: concluida\n",
    f"nota 4: verificada por op{int(digest[28:30], 16) % 90:02d}\n",
]
keep_content = [
    f"Licenca interna {token}.\n",
    "Uso restrito ao laboratorio.\n",
]

patch_text = "".join(difflib.unified_diff(conf_old, conf_new, f"a/{conf_name}", f"b/{conf_name}"))
patch_text += "".join(difflib.unified_diff(notes_old, notes_new, f"a/{notes_name}", f"b/{notes_name}"))

def flat(lines):
    return "".join(lines).rstrip("\n")

print(json.dumps({
    "work_dir": f"/srv/patchlab-{token}",
    "patch_file": f"/srv/ajustes-{token}.patch",
    "conf_name": conf_name,
    "notes_name": notes_name,
    "keep_name": "licenca.txt",
    "conf_content": flat(conf_old),
    "notes_content": flat(notes_old),
    "keep_content": flat(keep_content),
    "conf_expected": flat(conf_new),
    "notes_expected": flat(notes_new),
    "patch_text": patch_text.rstrip("\n"),
}, sort_keys=True))
