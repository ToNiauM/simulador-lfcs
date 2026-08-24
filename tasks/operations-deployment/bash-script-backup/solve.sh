#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

script_path="$(task_param script_path)"
archive_prefix="$(task_param archive_prefix)"

cat > "$script_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
src="\$1"
dest="\$2"
name="\$(basename "\$src")"
tar -czf "\$dest/${archive_prefix}-\${name}.tar.gz" -C "\$src" .
EOF
chmod 755 "$script_path"
