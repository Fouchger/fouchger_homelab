#!/usr/bin/env bash
# =============================================================================
# Filename: lib/menu/menus/00_07_00_ansible_menu.sh
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
# Main Menu Option:   7 "🛠️  Configure services (Ansible)"
#------------------------
ansible_menu() {
  while true; do
    local choice=""
    ui_menu "🛠️  Configure services (Ansible)" "Choose an action:" choice \
      1 "🧩 Service 1" \
      2 "🧩 Service 2" \
      3 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
    
      1) service1 ;;
      2) service2 ;;
      3) return 0 ;;
      *) return 0 ;;
    esac
  done
}