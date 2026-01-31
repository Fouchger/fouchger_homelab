#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Command entrypoint (menu).
# Purpose: Implements one discrete action invoked by homelab.sh or the menu.
# Usage:
#   ./commands/menu.sh
#   ./commands/menu.sh --action diagnostics
#   HOMELAB_DEFAULT_CHOICE=diagnostics ./commands/menu.sh   (headless default)
# Prerequisites:
#   - Project bootstrapped (see bootstrap.sh)
# Notes:
#   - Sprint 2 delivers menu routing and diagnostics navigation only (read-only).
#   - This script follows the command runner contract in lib/command_runner.sh.
#   - Works across Proxmox LXC/VM contexts where /dev/tty or TERM may be absent.
# -----------------------------------------------------------------------------

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/command_runner.sh"

menu_impl() {
  # Main menu loop (Sprint 2: routing + diagnostics only, read-only).
  # This command owns the interactive experience for the current run.

  # Source command implementations so we can call them within the same run.
  # Each command script is guarded (won't execute main when sourced).
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/diagnostics.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/profiles.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/selections.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/apps_install.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/apps_uninstall.sh"

  # Optional single-action routing for automation/headless runs.
  # Supported tags: diagnostics, exit
  local action=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --action)
        action="${2:-}"
        shift 2
        ;;
      --noninteractive)
        # Convenience flag: forces UI to avoid dialog/text prompts.
        export HOMELAB_UI_MODE="console"
        shift
        ;;
      -h|--help)
        ui_info "Menu help" "Options:\n  --action <diagnostics|exit>\n  --noninteractive\n\nEnvironment:\n  HOMELAB_DEFAULT_CHOICE=diagnostics\n  HOMELAB_UI_MODE=auto|dialog|plain|console"
        return 0
        ;;
      *)
        # Preserve forward compatibility: ignore unknown args but log.
        log_warn "menu: ignoring unknown argument: $1" || true
        shift
        ;;
    esac
  done

  if [[ -n "${action}" ]]; then
    case "${action}" in
      diagnostics)
        log_section "Menu: diagnostics (action)" || true
        diagnostics_impl || true
        runtime_summary_line "menu action completed: diagnostics" || true
        return 0
        ;;
      exit)
        log_info "Menu action exit selected" || true
        runtime_summary_line "menu action completed: exit" || true
        return 0
        ;;
      *)
        ui_warn "Unknown action" "Action not recognised: ${action}" || true
        runtime_summary_line "menu action failed: unknown action" || true
        return 0
        ;;
    esac
  fi

  ui_info "@welcome" "fouchger_homelab" "Welcome. Sprint 3 provides profile selection and app install/uninstall, plus diagnostics."

  # If UI is fully headless, ui_menu will return HOMELAB_DEFAULT_CHOICE (or empty).
  local choice
  while true; do
    choice="$(ui_menu "@main" "Main menu" "Choose an option"       "profiles" "Select profile"       "selections" "Manual app selection"       "apps_install" "Install selected apps"       "apps_uninstall" "Uninstall selected apps"       "diagnostics" "Diagnostics"       "exit" "Exit")"

    case "${choice}" in
      diagnostics)
        log_section "Menu: diagnostics" || true
        diagnostics_impl || true
        ;;
      profiles)
        log_section "Menu: profiles" || true
        profiles_impl --tier admin || true
        ;;
      selections)
        log_section "Menu: selections" || true
        selections_impl || true
        ;;
      apps_install)
        log_section "Menu: apps_install" || true
        apps_install_impl || true
        ;;
      apps_uninstall)
        log_section "Menu: apps_uninstall" || true
        apps_uninstall_impl || true
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

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
