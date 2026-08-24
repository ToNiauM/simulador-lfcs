#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

program_path="$(task_param program_path)"
output_dir="$(task_param output_dir)"
stdout_file="$(task_param stdout_file)"
stderr_file="$(task_param stderr_file)"
stdout_content="$(task_param stdout_content)"
stderr_content="$(task_param stderr_content)"

mkdir -p "$(dirname "$program_path")"
{
  echo '#!/usr/bin/env bash'
  printf 'cat <<"LFCS_OUT"\n%s\nLFCS_OUT\n' "$stdout_content"
  printf 'cat <<"LFCS_ERR" >&2\n%s\nLFCS_ERR\n' "$stderr_content"
} > "$program_path"
chmod 755 "$program_path"
rm -f "$output_dir/$stdout_file" "$output_dir/$stderr_file"
mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-essential-commands/redirect-command-output}" > /var/lib/lfcs-simulator/current-task
