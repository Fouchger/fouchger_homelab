#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/apps_uninstall.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Command entrypoint (apps_uninstall).
# Purpose: Implements one discrete action invoked by homelab.sh or the menu.
# Usage:
#   ./commands/apps_uninstall.sh
# Prerequisites:
#   - Project bootstrapped (see bootstrap.sh)
# Notes:
#   - Placeholder: implementation lands in a future sprint.
#   - This script follows the command runner contract in lib/command_runner.sh.
# -----------------------------------------------------------------------------

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/command_runner.sh"

apps_uninstall_impl() {
  ui_info "Not implemented yet" "apps_uninstall.sh is a placeholder. See docs/specs for the contract."
  return 0
}

main() {
  command_run "apps_uninstall" apps_uninstall_impl "$@"
}

main "$@"
