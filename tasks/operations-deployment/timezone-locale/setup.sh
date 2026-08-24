#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/task-lib.sh"
require_guest_root

# Deterministic starting point that always differs from every task timezone.
timedatectl set-timezone Etc/UTC

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
  *debian*|*ubuntu*)
    command -v locale-gen >/dev/null || { echo "locale-gen not found; the locales package is required (network installs are forbidden in lab)" >&2; exit 69; }
    ;;
  *rhel*|*fedora*|*centos*)
    # Locales ship precompiled via glibc-langpack packages; solve.sh verifies
    # that the requested locale is actually available.
    command -v localectl >/dev/null || { echo "localectl not found; systemd is required (network installs are forbidden in lab)" >&2; exit 69; }
    ;;
  *) echo "unsupported distro" >&2; exit 65 ;;
esac

mkdir -p /var/lib/lfcs-simulator
printf '%s\n' "${LFCS_TASK_ID:-operations-deployment/timezone-locale}" > /var/lib/lfcs-simulator/current-task
