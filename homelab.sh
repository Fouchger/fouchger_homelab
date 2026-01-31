#!/usr/bin/env bash
# ==============================================================================
# File: homelab.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Primary entrypoint for the homelab menu and commands.
# Purpose: Initialises environment, logging, and routes to the selected command/menu.
# Usage:
#   ./homelab.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# ==========================================================
# Filename: homelab.sh
# Created:  2026-01-31
# Updated:  2026-01-31
# Description:
#   Primary entrypoint for the fouchger_homelab menu runtime.
# Purpose:
#   - Hand off to the menu command (Sprint 2 onwards).
# Usage:
#   ./homelab.sh
# Prerequisites:
#   - Project bootstrapped (see bootstrap.sh)
#   - bash, git (for some flows), dialog (recommended for UI)
# Notes:
#   - homelab.sh is the human-friendly entrypoint.
#   - The command runner owns runtime lifecycle; this wrapper simply routes to it.
# ==========================================================
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

main() {
  exec "${ROOT_DIR}/commands/menu.sh" "$@"
}

main "$@"
