#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

tz="$(task_param timezone)"
loc="$(task_param locale)"

timedatectl set-timezone "$tz"

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*) family=debian ;;
  *rhel*|*fedora*|*centos*) family=rhel ;;
  *) echo "unsupported distro" >&2; exit 65 ;;
esac

locale_available() {
  local wanted
  wanted="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '-')"
  locale -a 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '-' | grep -qx "$wanted"
}

if [[ "$family" == debian ]]; then
  locale-gen "$loc"
  if command -v update-locale >/dev/null; then
    update-locale "LANG=$loc"
  else
    printf 'LANG=%s\n' "$loc" > /etc/default/locale
  fi
else
  # RHEL family: locales come precompiled from glibc-langpack packages; the
  # lab forbids network installs, so fail clearly if the locale is missing.
  if ! locale_available "$loc"; then
    echo "locale $loc is not available on this system (locale -a); bake the matching glibc-langpack package into the guest image (no network installs in lab)" >&2
    exit 69
  fi
  localectl set-locale "LANG=$loc"
fi
