#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

dropin="$(task_param dropin_file)"

mkdir -p "$(dirname "$dropin")"
cat > "$dropin" <<'EOF'
[Journal]
Storage=persistent
EOF

mkdir -p /var/log/journal
systemd-tmpfiles --create --prefix /var/log/journal 2>/dev/null || true
systemctl restart systemd-journald
journalctl --flush 2>/dev/null || true
