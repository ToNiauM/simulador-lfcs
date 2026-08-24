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
dest_net = networks[(index + 1) % len(networks)]
print(json.dumps({
    "lab_nic": "enp0s5",
    "lab_ip": f"{lab_net}.{10 + int(digest[8:10], 16) % 200}",
    "prefix_len": 24,
    "gateway": f"{lab_net}.{1 + int(digest[10:12], 16) % 9}",
    "dest_network": f"{dest_net}.0/24",
    "setup_netplan_file": f"/etc/netplan/91-lfcs-lab-{token}.yaml",
    "netplan_file": f"/etc/netplan/93-lfcs-route-{token}.yaml",
}, sort_keys=True))
