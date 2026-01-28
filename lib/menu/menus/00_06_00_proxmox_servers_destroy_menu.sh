#!/usr/bin/env bash
# =============================================================================
# Filename: lib/menu/menus/00_06_00_proxmox_servers_destroy_menu.sh
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
# Main Menu Option:   6 "🧯 Destroy VMs/LXCs (Terraform destroy)"
#------------------------
proxmox_servers_destroy_menu() {
  while true; do
    local choice=""
    ui_menu "🧯 Destroy VMs/LXCs (Terraform destroy)" "Choose an action:" choice \
      1 "🧯 LXC Ubuntu 24.04" \
      2 "🧯 VM Ubuntu 24.04" \
      3 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) destroy_lxc_ubuntu2404 ;;
      2) destroy_vm_ubuntu2404 ;;
      3) return 0 ;;
      *) return 0 ;;
    esac
  done
}