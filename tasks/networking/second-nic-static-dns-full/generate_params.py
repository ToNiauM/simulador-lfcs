#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
host_octet = 10 + int(digest[0:2], 16) % 200
dns1_octet = 211 + int(digest[2:4], 16) % 10
dns2_octet = 221 + int(digest[4:6], 16) % 10
print(json.dumps({
    "interface": "enp0s5",
    "address": f"198.51.100.{host_octet}/24",
    "route_to": "203.0.113.0/24",
    "route_via": "198.51.100.1",
    "dns_1": f"198.51.100.{dns1_octet}",
    "dns_2": f"198.51.100.{dns2_octet}",
    "search_domain": f"eng{token}.example",
}, sort_keys=True))
