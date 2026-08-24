#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

iface="$(task_param interface)"
domain1="$(task_param search_domain_1)"
domain2="$(task_param search_domain_2)"

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro: ${ID:-unknown}" >&2; exit 65 ;;
esac

if [[ "$family" == debian ]]; then
  # New numbered netplan file; existing files are left untouched.
  cat > /etc/netplan/60-lfcs-search.yaml <<EOF
network:
  version: 2
  ethernets:
    $iface:
      dhcp4: false
      optional: true
      nameservers:
        search: [$domain1, $domain2]
EOF
  chmod 600 /etc/netplan/60-lfcs-search.yaml
  netplan apply
else
  # NetworkManager: attach the search domains to the connection that owns the
  # interface, or create a minimal profile when none exists.
  con="$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)"
  if [[ -n "$con" && "$con" != "--" ]]; then
    nmcli con mod "$con" ipv4.dns-search "${domain1},${domain2}" 2>/dev/null \
      || nmcli con mod "$con" ipv6.dns-search "${domain1},${domain2}"
    nmcli con up "$con" >/dev/null
  else
    ctype="$(nmcli -g GENERAL.TYPE device show "$iface" 2>/dev/null || true)"
    [[ -n "$ctype" ]] || ctype=ethernet
    nmcli con delete lfcs-search >/dev/null 2>&1 || true
    nmcli con add type "$ctype" ifname "$iface" con-name lfcs-search \
      connection.autoconnect yes ipv4.method disabled ipv6.method link-local \
      ipv6.dns-search "${domain1},${domain2}" >/dev/null
    nmcli con up lfcs-search >/dev/null
  fi
fi
