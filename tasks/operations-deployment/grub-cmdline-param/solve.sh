#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

param="$(task_param cmdline_param)"

python3 - "$param" <<'PY'
import re, sys

param = sys.argv[1]
path = "/etc/default/grub"
lines = open(path).read().splitlines()
pattern = re.compile(r'^(\s*GRUB_CMDLINE_LINUX=)(["\']?)(.*?)\2(\s*(#.*)?)$')
indexes = [i for i, line in enumerate(lines) if pattern.match(line)]
if indexes:
    i = indexes[-1]
    match = pattern.match(lines[i])
    current = match.group(3).split()
    if param not in current:
        current.append(param)
    lines[i] = f'{match.group(1)}"{" ".join(current)}"{match.group(4)}'
else:
    lines.append(f'GRUB_CMDLINE_LINUX="{param}"')
open(path, "w").write("\n".join(lines) + "\n")
PY

if command -v update-grub >/dev/null; then
  update-grub
else
  grub-mkconfig -o /boot/grub/grub.cfg
fi
