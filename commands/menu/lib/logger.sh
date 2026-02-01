#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/lib/logger.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description:
#   Menu logger wrapper.
# Notes:
#   - Delegates to lib/logging.sh so the menu respects system log level.
# -----------------------------------------------------------------------------

# ROOT_DIR is expected to be set by lib/paths.sh in the menu entrypoint.
if [[ -n "${ROOT_DIR:-}" && -f "${ROOT_DIR%/}/lib/logging.sh" ]]; then
  # shellcheck disable=SC1090
  source "${ROOT_DIR%/}/lib/logging.sh"
fi

if ! command -v log_info >/dev/null 2>&1; then
  log_info() { printf '[menu] %s\n' "$*" >&2; }
fi

log() {
  # Keep existing call-sites working.
  log_info "[menu] $*"
}
