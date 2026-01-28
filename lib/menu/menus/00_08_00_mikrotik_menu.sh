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
# Main Menu Option:   8 "📡 MikroTik integration"
#------------------------
mikrotik_menu() {
  while true; do
    local choice=""
    ui_menu "📡 MikroTik integration" "Choose an action:" choice \
      1 "💾 Backup MikroTik now" \
      2 "🩺 Run health check now" \
      3 "🌐 Configure DHCP to advertise dns01 + dns02" \
      4 "🧾 Install start config locally" \
      5 "🚀 Apply start config to MikroTik" \
      0 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) scripts/mikrotik/backup.sh ;;
      2) scripts/mikrotik/healthcheck.sh ;;
      3) scripts/mikrotik/configure-dns.sh ;;
      4) scripts/mikrotik/install-start-config.sh ;;
      5) scripts/mikrotik/apply-start-config.sh ;;
      0) return 0 ;;
      *) return 0 ;;
    esac
  done
}