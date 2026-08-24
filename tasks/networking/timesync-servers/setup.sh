#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

ntp1="$(task_param ntp_server_1)"

# Idempotency: drop any previous config referencing our seeded servers, then
# make sure the time sync services start from a non-configured state.
if [[ -d /etc/systemd/timesyncd.conf.d ]]; then
  while IFS= read -r conf; do
    rm -f "$conf"
  done < <(grep -l -- "$ntp1" /etc/systemd/timesyncd.conf.d/*.conf 2>/dev/null || true)
fi
for dir in /etc/chrony/conf.d /etc/chrony/sources.d /etc/chrony.d; do
  [[ -d "$dir" ]] || continue
  while IFS= read -r conf; do
    rm -f "$conf"
  done < <(grep -l -- "$ntp1" "$dir"/* 2>/dev/null || true)
done
# Strip seeded server lines appended to a main chrony conf by a previous run.
domain="${ntp1#*.}"
domain_re="${domain//./\\.}"
for conf in /etc/chrony/chrony.conf /etc/chrony.conf; do
  [[ -f "$conf" ]] && sed -i "/$domain_re/d" "$conf" || true
done
systemctl disable --now systemd-timesyncd.service >/dev/null 2>&1 || true
systemctl disable --now chronyd.service >/dev/null 2>&1 || true
systemctl disable --now chrony.service >/dev/null 2>&1 || true

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-networking/timesync-servers}" > /var/lib/lfcs-simulator/current-task
