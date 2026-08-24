#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
token = digest[:6]
networks = ("192.0.2", "198.51.100", "203.0.113")
index = int(digest[6:8], 16) % len(networks)
lab_net = networks[index]
dns_net_1 = networks[(index + 1) % len(networks)]
dns_net_2 = networks[(index + 2) % len(networks)]
print(json.dumps({
    "lab_nic": "enp0s5",
    "lab_ip": f"{lab_net}.{10 + int(digest[8:10], 16) % 200}",
    "prefix_len": 24,
    "dns_server_1": f"{dns_net_1}.{10 + int(digest[10:12], 16) % 200}",
    "dns_server_2": f"{dns_net_2}.{10 + int(digest[12:14], 16) % 200}",
    "search_domain": f"lab{token}.example",
    "setup_netplan_file": f"/etc/netplan/91-lfcs-lab-{token}.yaml",
    "netplan_file": f"/etc/netplan/92-lfcs-dns-{token}.yaml",
}, sort_keys=True))
