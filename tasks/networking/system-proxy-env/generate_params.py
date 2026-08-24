#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
ports = (3128, 8080, 8888, 8118)
print(json.dumps({
    "proxy_host": f"proxy.{token}.example",
    "proxy_port": ports[int(digest[0:2], 16) % len(ports)],
    "no_proxy": f"localhost,127.0.0.1,.{token}.internal",
}, sort_keys=True))
