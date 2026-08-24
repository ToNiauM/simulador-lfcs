#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

tree_dir="$(task_param tree_dir)"
owner_user="$(task_param owner_user)"
owner_group="$(task_param owner_group)"
token="$(task_param fixture_token)"

groupadd -f "$owner_group"
id "$owner_user" &>/dev/null || useradd -m -s /bin/bash "$owner_user"

rm -rf "$tree_dir"
mkdir -p "$tree_dir"/{src,docs,build/cache}
for rel in src/main.c src/util.c docs/manual.txt build/cache/obj.bin build/output.log; do
  printf 'lfcs-fixture:%s:%s\n' "$token" "$rel" > "$tree_dir/$rel"
done
chown -R root:root "$tree_dir"

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/file-ownership-tree}" > /var/lib/lfcs-simulator/current-task
