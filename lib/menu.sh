#!/usr/bin/env bash
# =============================================================================
# Filename: lib/menu.sh
# Description: Menu and submenu routing (navigation only)
#
# Notes
#   - No direct operational logic here.
#   - Delegate to action_* functions in lib/actions.sh
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

#-----------------------------------------------------------------------------
# Main Menu Setup
#-----------------------------------------------------------------------------
bootstrap_dev_server_menu() {
  while true; do
    local choice=""
    ui_menu "Bootstrap Development Server" "Choose an action:" choice \
      1 "Install Code-Server" \
      2 "Bootstrap server - Configs and Setup" \
      3 "Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/coder-code-server.sh)" ;;
      2) scripts/core/bootstrap.sh ;;
      3) return 0 ;;
      *) return 0 ;;
    esac
  done
}


infrastructure_menu() {
  while true; do
    local choice=""
    ui_menu "Infrastructure" "Select an area:" choice \
      1 "Proxmox templates (Plasceholder)" \
      2 "MikroTik integration (Plasceholder)" \
      3 "DNS services (Plasceholder)" \
      4 "Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) action_open_proxmox_templates ;;
      2) action_open_mikrotik_menu ;;
      3) action_open_dns_menu ;;
      4) return 0 ;;
      *) return 0 ;;
    esac
  done
}

workflows_menu() {
  while true; do
    local choice=""
    ui_menu "Workflows" "Choose a workflow:" choice \
      1 "Run questionnaires (Plasceholder)" \
      2 "Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) action_run_questionnaires ;;
      2) return 0 ;;
      *) return 0 ;;
    esac
  done
}

#-----------------------------------------------------------------------------
# Main Menu Setup
#-----------------------------------------------------------------------------
main_menu() {
  ui_init

  while true; do
    local choice=""
    ui_menu "Fouchger_Homelab" "Choose an action:" choice \
      1. Git & Github Management \
      2. Bootstrap Development Server (admin01) \
      3. Infrastructure (Plasceholder) \
      4. Workflows (Plasceholder) \
      5. App Manager (LXC tools) (Plasceholder) \
      6. Exit


    [[ -n "${choice}" ]] || break

    case "${choice}" in
      1) scripts/core/dev-auth.sh ;;
      2) bootstrap_menu ;;
      3) infrastructure_menu ;;
      4) workflows_menu ;;
      5) action_open_app_manager ;;
      6) break ;;
      *) break ;;
    esac
  done

  ui_exit
}
