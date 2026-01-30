#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/proxmox_access.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Command entrypoint (proxmox_access).
# Purpose: Implements one discrete action invoked by homelab.sh or the menu.
# Usage:
#   ./commands/proxmox_access.sh
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

proxmox_access_impl() {
  ui_info "Not implemented yet" "proxmox_access.sh is a placeholder. See docs/specs for the contract."
  return 0
}

main() {
  command_run "proxmox_access" proxmox_access_impl "$@"
}

main "$@"
