#!/usr/bin/env bash
# =============================================================================
# Filename: lib/menu/menus/00_03_00_proxmox_configure_menu.sh
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
# Main Menu Option:   3 "🔐 Configure Proxmox API token"
#------------------------
proxmox_configure_menu() {
  while true; do
    local choice=""
    ui_menu "🔐 Configure Proxmox API token" "Choose an action:" choice \
      1 "🔑 Configure token now" \
      3 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) proxmox ;;
      3) return 0 ;;
      *) return 0 ;;
    esac
  done
}