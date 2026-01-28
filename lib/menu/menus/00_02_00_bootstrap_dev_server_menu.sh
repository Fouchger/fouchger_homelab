#!/usr/bin/env bash
# =============================================================================
# Filename: lib/menu/menus/00_02_00_bootstrap_dev_server_menu.sh
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
source "${REPO_ROOT}/lib/menu/menus/00_02_02_app_manager_menu.sh"

#------------------------
# Main Menu Option:   2 "🧰 Bootstrap Development Server (admin01)"
#------------------------
bootstrap_dev_server_menu() {
  while true; do
    local choice=""
    ui_menu "Bootstrap Development Server" "Choose an action:" choice \
      1 "🧑‍💻 Install Code-Server" \
      2 "🧰 Bootstrap server - Configs and Setup" \
      3 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1)
        ui_confirm "External script" "This will download and run a third-party script from GitHub.\n\nProceed?" || continue
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/coder-code-server.sh)"
        ;;
      2) app_manager_menu ;;
      3) return 0 ;;
      *) return 0 ;;
    esac
  done
}