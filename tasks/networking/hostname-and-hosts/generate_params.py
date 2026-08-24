#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
networks = ("192.0.2", "198.51.100", "203.0.113")
index = int(digest[6:8], 16) % len(networks)
net_a = networks[index]
net_b = networks[(index + 1) % len(networks)]
domain = f"lab{token}.example"
host_a = f"app-{digest[8:13]}"
host_b = f"db-{digest[13:18]}"
print(json.dumps({
    "new_hostname": f"lab-{token}",
    "hosts_domain": domain,
    "host_a": host_a,
    "fqdn_a": f"{host_a}.{domain}",
    "ip_a": f"{net_a}.{20 + int(digest[18:20], 16) % 200}",
    "host_b": host_b,
    "fqdn_b": f"{host_b}.{domain}",
    "ip_b": f"{net_b}.{20 + int(digest[20:22], 16) % 200}",
}, sort_keys=True))
