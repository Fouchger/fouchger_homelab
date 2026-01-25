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

if [[ -z "${REPO_ROOT:-}" ]]; then
  REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi

#=============================================================================
# Sub Menu Setup
#=============================================================================

#------------------------
# Main Menu Option:   2 "Bootstrap Development Server (admin01)"
# Sub Menu:           bootstrap_dev_server_menu() - "Bootstrap Development Server"
# Option:             2 "Bootstrap server - Configs and Setup"
#------------------------
app_manager_menu() {
  while true; do
    local choice=""
    ui_menu "Ubuntu App Manager - Run Local" "Choose an action:" choice \
      1 "Apply profile (replace selections)" \
      2 "Apply profile (add to selections)" \
      3 "Change selections" \
      4 "Apply install/uninstall" \
      5 "Edit version pins" \
      7 "check which apps are installed" \
      6 "Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) choose_and_apply_profile_replace ;;
      2) choose_and_apply_profile_add ;;
      3) run_checklist ;;
      4) apply_changes ;;
      5) edit_version_pins ;;
      7) audit_selected_apps ;;
      6) return 0 ;;
    esac
  done
}

#------------------------
# Main Menu Option:   2 "Bootstrap Development Server (admin01)"
#------------------------
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

#------------------------
# Main Menu Option:   3 "Infrastructure"
#------------------------
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

#------------------------
# Main Menu Option:   4 "Workflows"
#------------------------
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

#------------------------
# Main Menu Option:   5 "Debug"
#------------------------
debug_menu() {
  while true; do
    local choice=""
    ui_menu "Debug" "Diagnostics and troubleshooting tools:" choice \
      1 "Session capture: Enable" \
      2 "Session capture: Disable" \
      3 "Session capture: Status" \
      4 "Session capture: Show last 200 lines" \
      5 "Session capture: Live tail (Ctrl+C to exit)" \
      6 "Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1)
        "${REPO_ROOT}/scripts/core/session_capture.sh" on >/dev/null 2>&1 || true
        ui_msgbox "Session capture" "Enabled. It will auto-start next time you run 'make menu'."
        make menu
        debug_menu
        ;;
      2)
        "${REPO_ROOT}/scripts/core/session_capture.sh" off >/dev/null 2>&1 || true
        ui_msgbox "Session capture" "Disabled."
        make menu
        debug_menu
        ;;
      3)
        local tmp
        tmp="$(ui_tmpfile session_capture_status)"
        "${REPO_ROOT}/scripts/core/session_capture.sh" status >"${tmp}" 2>&1 || true
        ui_textbox "Session capture status" "${tmp}" || true
        ;;
      4)
        local tmp
        tmp="$(ui_tmpfile session_capture_tail)"
        if [[ -f "${HOME}/.ptlog/current.log" ]]; then
          tail -n 200 "${HOME}/.ptlog/current.log" >"${tmp}" 2>&1 || true
          ui_textbox "Session capture last 200 lines" "${tmp}" || true
        else
          ui_msgbox "Session capture" "No current log found at ${HOME}/.ptlog/current.log"
        fi
        ;;
      5)
        # Running a live tail inside dialog is clunky. We exit UI, run tail, then return.
        ui_exit
        if command -v ptlog >/dev/null 2>&1; then
          ptlog tail || true
        elif [[ -f "${HOME}/.ptlog/current.log" ]]; then
          tail -f "${HOME}/.ptlog/current.log" || true
        else
          printf '%s\n' "No current log found. Enable capture and run a workflow first." >&2
        fi
        ui_init
        ;;
      6) return 0 ;;
      *) return 0 ;;
    esac
  done
}

#------------------------
# Main Menu Option:   6 "Generate Project Documentation"
#------------------------
documentation_menu() {
  while true; do
    local choice=""
    ui_menu "Generate Project Documentation" "Choose an action:" choice \
      1 "Install required python libraries" \
      2 "Generate documentation" \
      3 "Clear document creation data" \
      4 "Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) make preflight ;;
      2) make docs ;;
      3) make docs-clean ;;
      4) return 0 ;;
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
      5 "Debug" \
      6 "Generate Project Documentation" \
      7 Exit

    [[ -n "${choice}" ]] || break

    case "${choice}" in
      1) "${REPO_ROOT}/scripts/core/dev-auth.sh" ;;
      2) bootstrap_dev_server_menu ;;
      3) infrastructure_menu ;;
      4) workflows_menu ;;
      5) debug_menu ;;
      6) documentation_menu ;; 
      7) break ;;
      *) break ;;
    esac
  done

  ui_exit
}
