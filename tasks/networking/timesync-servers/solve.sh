#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro family" >&2; exit 65 ;;
esac

ntp1="$(task_param ntp_server_1)"
ntp2="$(task_param ntp_server_2)"
fallback="$(task_param fallback_server)"

if [[ "$family" == debian ]]; then
  mkdir -p /etc/systemd/timesyncd.conf.d
  cat > /etc/systemd/timesyncd.conf.d/50-lfcs.conf <<EOF
[Time]
NTP=$ntp1 $ntp2
FallbackNTP=$fallback
EOF
  systemctl enable systemd-timesyncd.service
  systemctl restart systemd-timesyncd.service
else
  conf=/etc/chrony.conf
  [[ -f "$conf" ]] || conf=/etc/chrony/chrony.conf
  [[ -f "$conf" ]] || { echo "chrony configuration file not found" >&2; exit 69; }
  # Append seeded servers; the stock configuration is never overwritten.
  {
    echo "server $ntp1 iburst"
    echo "server $ntp2 iburst"
    echo "server $fallback iburst"
  } >> "$conf"
  systemctl enable chronyd.service
  systemctl restart chronyd.service
fi
