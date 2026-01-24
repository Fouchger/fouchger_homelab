#!/usr/bin/env bash
# =============================================================================
# Filename: lib/menu.sh
# Description: Menu and submenu routing (navigation only)
#
# Notes
#   - No direct operational logic here.
#   - Delegate to action_* functions in lib/actions.sh
# =============================================================================
echo "lib/menu.sh"
set -Eeuo pipefail
IFS=$'\n\t'

if [[ -z "${REPO_ROOT:-}" ]]; then
  REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi

#-----------------------------------------------------------------------------
# Sub Menu Setup
#-----------------------------------------------------------------------------
app_manager_menu() {
  while true; do
    local choice=""
    ui_menu "Ubuntu App Manager - Run Local" "Choose an action:" choice \
      1 "Apply profile (replace selections)" \
      2 "Apply profile (add to selections)" \
      3 "Change selections" \
      4 "Apply install/uninstall" \
      5 "Edit version pins" \
      6 "Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) choose_and_apply_profile_replace ;;
      2) choose_and_apply_profile_add ;;
      3) run_checklist ;;
      4) apply_changes ;;
      5) edit_version_pins ;;
      6) return 0 ;;
    esac
  done
}

bootstrap_dev_server_menu() {
  while true; do
    local choice=""
    ui_menu "Bootstrap Development Server" "Choose an action:" choice \
      1 "Install Code-Server" \
      2 "Bootstrap server - Configs and Setup" \
      3 "Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1)
        ui_confirm "External script" "This will download and run a third-party script from GitHub.\n\nProceed?" || continue
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/coder-code-server.sh)" ;;
      2) app_manager_menu ;;
      3) return 0 ;;
      *) return 0 ;;
    esac
  done
}

infrastructure_menu() {
  while true; do
    local choice=""
    ui_menu "Infrastructure" "Select an area:" choice \
      1 "Proxmox templates" \
      2 "MikroTik integration" \
      3 "DNS services" \
      4 "Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
  1)
        feature_require "PROXMOX" "Proxmox templates are not enabled yet on this host.

To enable:
  state_set FEATURE_PROXMOX 1" \
          && action_open_proxmox_templates ;;
      2)
        feature_require "MIKROTIK" "MikroTik integration is currently disabled on this host.

To enable:
  state_set FEATURE_MIKROTIK 1" \
          && action_open_mikrotik_menu ;;
      3)
        feature_require "DNS" "DNS services are currently disabled on this host.

To enable:
  state_set FEATURE_DNS 1" \
          && action_open_dns_menu ;;
      4) return 0 ;;
      *) return 0 ;;
    esac
  done
}

workflows_menu() {
  while true; do
    local choice=""
    ui_menu "Workflows" "Choose a workflow:" choice \
      1 "Run questionnaires" \
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
      1 "Git & Github Management" \
      2 "Bootstrap Development Server (admin01)" \
      3 "Infrastructure" \
      4 "Workflows" \
      6 Exit

    [[ -n "${choice}" ]] || break

    case "${choice}" in
      1) "${REPO_ROOT}/scripts/core/dev-auth.sh" ;;
      2) bootstrap_dev_server_menu ;;
      3) infrastructure_menu ;;
      4) workflows_menu ;;
      6) break ;;
      *) break ;;
    esac
  done

  ui_exit
}
