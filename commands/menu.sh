#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Command entrypoint (menu).
# Purpose: Implements one discrete action invoked by homelab.sh or the menu.
# Usage:
#   ./commands/menu.sh
# Prerequisites:
#   - Project bootstrapped (see bootstrap.sh)
# Notes:
#   - Sprint 2 delivers menu routing and diagnostics navigation only (read-only).
#   - This script follows the command runner contract in lib/command_runner.sh.
# -----------------------------------------------------------------------------

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/command_runner.sh"

menu_impl() {
  # Main menu loop (Sprint 2: routing + diagnostics only, read-only).
  # This command owns the interactive experience for the current run.

  # Source diagnostics implementation so we can call it within the same run.
  # diagnostics.sh is guarded so it will not execute main when sourced.
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/diagnostics.sh"

  ui_info "fouchger_homelab" "Welcome. Sprint 2 provides read-only navigation and diagnostics."

  local choice
  while true; do
    choice="$(ui_menu "Main menu" "Choose an option" \
      "diagnostics" "Diagnostics (read-only)" \
      "exit" "Exit")"

    case "${choice}" in
      diagnostics)
        log_section "Menu: diagnostics" || true
        diagnostics_impl || true
        ;;
      exit|"")
        log_info "Menu exit selected" || true
        break
        ;;
      *)
        ui_warn "Unknown option" "Selection not recognised: ${choice}" || true
        ;;
    esac
  done

  runtime_summary_line "menu completed" || true
  return 0
}

main() {
  command_run "menu" menu_impl "$@"
}

main "$@"
