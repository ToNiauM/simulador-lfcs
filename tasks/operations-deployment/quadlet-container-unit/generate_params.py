#!/usr/bin/env python3
import hashlib
import json
import sys

seed = sys.argv[1] if len(sys.argv) == 2 else ""
digest = hashlib.sha256(seed.encode()).hexdigest()
images = (
    ("docker.io/library/nginx:1.27", 80),
    ("docker.io/library/httpd:2.4", 80),
    ("docker.io/library/redis:7.2", 6379),
)
image, container_port = images[int(digest[10:12], 16) % len(images)]
unit_basename = f"web{digest[:5]}"
print(json.dumps({
    "unit_basename": unit_basename,
    "container_file": f"/etc/containers/systemd/{unit_basename}.container",
    "image": image,
    "host_port": 8000 + int(digest[12:15], 16) % 1000,
    "container_port": container_port,
    "env_name": "LFCS_MODE",
    "env_value": digest[15:21],
}, sort_keys=True))
