#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/profiles.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Command entrypoint (profiles).
# Purpose: Implements one discrete action invoked by homelab.sh or the menu.
# Usage:
#   ./commands/profiles.sh
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

profiles_impl() {
  ui_info "Not implemented yet" "profiles.sh is a placeholder. See docs/specs for the contract."
  return 0
}

main() {
  command_run "profiles" profiles_impl "$@"
}

main "$@"
