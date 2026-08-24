#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
vlan_id = 100 + int(digest[6:10], 16) % 3800
host = 1 + int(digest[10:12], 16) % 250
print(json.dumps({
    "nic": "enp0s5",
    "vlan_id": vlan_id,
    "vlan_iface": f"vlan{vlan_id}",
    "vlan_ip": f"198.51.100.{host}/24",
}, sort_keys=True))
