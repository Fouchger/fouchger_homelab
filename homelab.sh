#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: homelab.sh
# Created: 2026-01-31
# Updated: 2026-02-01
# Description:
#   Primary entrypoint for the homelab menu and commands.
#
# Usage:
#   ./homelab.sh
#
# Environment variables:
#   CATPPUCCIN_FLAVOUR  One of LATTE|FRAPPE|MACCHIATO|MOCHA (default: MOCHA)
#   HOMELAB_THEME       Alias for CATPPUCCIN_FLAVOUR (optional)
#
# Notes:
#   - ROOT_DIR is resolved via lib/paths.sh.
#   - This wrapper sets the theme and hands off to the menu.
# -----------------------------------------------------------------------------

set -euo pipefail

# Resolve repository root.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)/lib/paths.sh"

main() {
  # Allow a single knob to set the theme.
  export CATPPUCCIN_FLAVOUR="${CATPPUCCIN_FLAVOUR:-${HOMELAB_THEME:-MOCHA}}"
  exec "${ROOT_DIR}/commands/menu/menu.sh" "$@"
}

main "$@"