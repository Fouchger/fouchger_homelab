#!/usr/bin/env bash
# =============================================================================
# Filename: lib/menu/menus/00_02_02_app_manager_menu.sh
# Created: 28/01/2026
# Updated: 28/01/2026
# Description: 
#
# Notes
#   - 
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

if [[ -z "${REPO_ROOT:-}" ]]; then
  REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi

#=============================================================================
# Sub Menu Setup
#=============================================================================
# source "${REPO_ROOT}/lib/menu/menus/<sub menu file name>.sh

#------------------------
# Main Menu Option:   2 "🧰 Bootstrap Development Server (admin01)"
# Sub Menu:           bootstrap_dev_server_menu()
# Option:             2 "Bootstrap server - Configs and Setup"
#------------------------
app_manager_menu() {
  while true; do
    local choice=""
    ui_menu "Ubuntu App Manager - Run Local" "Choose an action:" choice \
      1 "🧾 Apply profile (replace selections)" \
      2 "➕ Apply profile (add to selections)" \
      3 "📝 Change selections" \
      4 "🚀 Apply install/uninstall" \
      5 "📌 Edit version pins" \
      6 "🔍 Check which apps are installed" \
      7 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) choose_and_apply_profile_replace ;;
      2) choose_and_apply_profile_add ;;
      3) run_checklist ;;
      4) apply_changes ;;
      5) edit_version_pins ;;
      6) audit_selected_apps ;;
      7) return 0 ;;
    esac
  done
}