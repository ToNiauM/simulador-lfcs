#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
timezones = ("America/Sao_Paulo", "Europe/Lisbon", "Asia/Tokyo", "Australia/Sydney", "Africa/Nairobi")
locales = ("pt_BR.UTF-8", "de_DE.UTF-8", "fr_FR.UTF-8", "es_ES.UTF-8", "nl_NL.UTF-8")
print(json.dumps({
    "timezone": timezones[int(digest[0:2], 16) % len(timezones)],
    "locale": locales[int(digest[2:4], 16) % len(locales)],
}, sort_keys=True))
