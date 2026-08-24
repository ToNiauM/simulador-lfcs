#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

tz="$(task_param timezone)"
loc="$(task_param locale)"

timedatectl set-timezone "$tz"
locale-gen "$loc"
if command -v update-locale >/dev/null; then
  update-locale "LANG=$loc"
else
  printf 'LANG=%s\n' "$loc" > /etc/default/locale
fi
