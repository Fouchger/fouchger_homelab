#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/core/session_capture.sh
# Created:  2026-01-25
# Description: Manage Layer 2 session capture (Pentest-Terminal-Logger: ptlog).
#
# Usage:
#   scripts/core/session_capture.sh on
#   scripts/core/session_capture.sh off
#   scripts/core/session_capture.sh status
#   scripts/core/session_capture.sh tail
#
# Notes:
#   - Feature flag: FEATURE_SESSION_CAPTURE=1 (stored in state.env)
#   - ptlog stores state under ~/.ptlog/ and exposes a current log symlink
#     at ~/.ptlog/current.log.
#   - `tail` runs `ptlog tail` if available (interactive, blocks).
# Maintainer: Gert
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

REPO_ROOT="${REPO_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)}"
export REPO_ROOT

# shellcheck source=lib/modules.sh
source "${REPO_ROOT}/lib/modules.sh"
homelab_load_lib

# shellcheck source=lib/state.sh
source "${REPO_ROOT}/lib/state.sh"

cmd="${1:-status}"

ptlog_installed() {
  command -v ptlog >/dev/null 2>&1
}

flag_set() {
  state_set FEATURE_SESSION_CAPTURE "$1"
}

flag_get() {
  state_get FEATURE_SESSION_CAPTURE "0"
}

show_status() {
  local flag
  flag="$(flag_get)"
  echo "Feature flag FEATURE_SESSION_CAPTURE=${flag}"

  if ptlog_installed; then
    ptlog status || true
    if [[ -f "${HOME}/.ptlog/current.log" ]]; then
      echo "Current log: ${HOME}/.ptlog/current.log"
      echo "Tail (last 30 lines):"
      tail -n 30 "${HOME}/.ptlog/current.log" || true
    fi
  else
    echo "ptlog: not installed (Layer 2 will not start automatically)"
  fi
}

case "$cmd" in
  on)
    flag_set 1
    echo "Layer 2 session capture: ENABLED (will auto-start next time you run 'make menu')"
    show_status
    ;;
  off)
    flag_set 0
    echo "Layer 2 session capture: DISABLED"
    if ptlog_installed; then
      ptlog stop || true
      ptlog status || true
    fi
    ;;
  status)
    show_status
    ;;
  tail)
    if ptlog_installed; then
      ptlog tail
    elif [[ -f "${HOME}/.ptlog/current.log" ]]; then
      tail -f "${HOME}/.ptlog/current.log"
    else
      echo "No current log found to tail. Install ptlog and enable capture first."
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 {on|off|status|tail}" >&2
    exit 2
    ;;
esac
