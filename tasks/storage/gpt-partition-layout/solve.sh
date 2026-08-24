#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

disk="$(task_param target_disk)"
p1="$(task_param part1_size_mib)"
p2="$(task_param part2_size_mib)"

sfdisk --wipe always "$disk" <<SF
label: gpt
,${p1}MiB
,${p2}MiB
SF
udevadm settle 2>/dev/null || true
