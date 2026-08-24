#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

script_path="$(task_param script_path)"
expected_argc="$(task_param expected_argc)"
error_exit_code="$(task_param error_exit_code)"

cat > "$script_path" <<EOF
#!/usr/bin/env bash
if [[ \$# -ne ${expected_argc} ]]; then
  echo "usage: \$(basename "\$0") expects ${expected_argc} arguments" >&2
  exit ${error_exit_code}
fi
for ((i = \$#; i >= 1; i--)); do
  printf '%s\n' "\${!i}" | tr '[:lower:]' '[:upper:]'
done
exit 0
EOF
chmod 755 "$script_path"
