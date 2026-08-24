#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
networks = ("192.0.2", "198.51.100", "203.0.113")
network = networks[int(digest[6:8], 16) % len(networks)]
host = 10 + int(digest[8:10], 16) % 200
print(json.dumps({
    "lab_nic": "enp0s5",
    "ip_address": f"{network}.{host}",
    "prefix_len": 24,
    "netplan_file": f"/etc/netplan/90-lfcs-{token}.yaml",
}, sort_keys=True))
