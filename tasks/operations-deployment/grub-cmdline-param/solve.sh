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

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro" >&2; exit 65 ;;
esac

if [[ "$family" == debian ]]; then
  if command -v update-grub >/dev/null; then
    update-grub
  else
    grub-mkconfig -o /boot/grub/grub.cfg
  fi
else
  regenerated=0
  # BLS entries (/boot/loader/entries/*.conf) get the parameter via grubby.
  if command -v grubby >/dev/null; then
    grubby --update-kernel=ALL --args="$param"
    regenerated=1
  fi
  # Regenerate grub.cfg as well when the tool is present.
  if command -v grub2-mkconfig >/dev/null && [[ -f /boot/grub2/grub.cfg ]]; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
    regenerated=1
  fi
  [[ "$regenerated" == 1 ]] || { echo "neither grubby nor grub2-mkconfig usable; cannot regenerate boot configuration" >&2; exit 69; }
fi
