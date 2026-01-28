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

source "${REPO_ROOT}/lib/menu/menus/00_02_00_bootstrap_dev_server_menu.sh"
source "${REPO_ROOT}/lib/menu/menus/00_03_00_proxmox_configure_menu.sh"
source "${REPO_ROOT}/lib/menu/menus/00_04_00_proxmox_templates_download_menu.sh"
source "${REPO_ROOT}/lib/menu/menus/00_05_00_proxmox_servers_create_menu.sh"
source "${REPO_ROOT}/lib/menu/menus/00_06_00_proxmox_servers_destroy_menu.sh"
source "${REPO_ROOT}/lib/menu/menus/00_07_00_ansible_menu.sh"
source "${REPO_ROOT}/lib/menu/menus/00_08_00_mikrotik_menu.sh"

#------------------------
# Main Menu Option:   2 "template"
# Sub Menu:           template_menu()
#------------------------
template_menu() {
  while true; do
    local choice=""
    ui_menu "Template" "Choose an action:" choice \
      1 "🧪 Run template action" \
      3 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) template ;;
      3) return 0 ;;
      *) return 0 ;;
    esac
  done
}





#------------------------
# Main Menu Option:   11 "Generate Project Documentation"
#------------------------
documentation_menu() {
  while true; do
    local choice=""
    ui_menu "📚 Generate Project Documentation" "Choose an action:" choice \
      1 "🧩 Install required python libraries" \
      2 "📝 Generate documentation" \
      3 "🧹 Clear document creation data" \
      4 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) make docs-preflight ;;
      2) make docs ;;
      3) make docs-clean ;;
      4) return 0 ;;
      *) return 0 ;;
    esac
  done
}

#------------------------
# Main Menu Option:   12 "Infrastructure"
#------------------------
infrastructure_menu() {
  while true; do
    local choice=""
    ui_menu "🏗️ Infrastructure" "Select an area:" choice \
      1 "📦 Proxmox templates" \
      2 "📡 MikroTik integration" \
      3 "🌐 DNS services" \
      4 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1)
        feature_require "PROXMOX" "Proxmox templates are not enabled yet on this host.

To enable:
  state_set FEATURE_PROXMOX 1" \
          && action_open_proxmox_templates
        ;;
      2)
        feature_require "MIKROTIK" "MikroTik integration is currently disabled on this host.

To enable:
  state_set FEATURE_MIKROTIK 1" \
          && action_open_mikrotik_menu
        ;;
      3)
        feature_require "DNS" "DNS services are currently disabled on this host.

To enable:
  state_set FEATURE_DNS 1" \
          && action_open_dns_menu
        ;;
      4) return 0 ;;
      *) return 0 ;;
    esac
  done
}

#------------------------
# Main Menu Option:   13 "Workflows"
#------------------------
workflows_menu() {
  while true; do
    local choice=""
    ui_menu "🔁 Workflows" "Choose a workflow:" choice \
      1 "✅ Validate configuration" \
      2 "🧾 Run questionnaires" \
      3 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) action_validate_configuration ;;
      2) action_run_questionnaires ;;
      3) return 0 ;;
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
      1 "🧑‍💻 Git & GitHub Management" \
      2 "🧰 Bootstrap Development Server (admin01)" \
      3 "🔐 Configure Proxmox API token" \
      4 "📦 Download Proxmox templates" \
      5 "🏗️ Provision or update VMs/LXCs (Terraform apply)" \
      6 "🧯 Destroy VMs/LXCs (Terraform destroy)" \
      7 "🛠️ Configure services (Ansible)" \
      8 "📡 MikroTik integration" \
      9 "🐞 Debug" \
      10 "📂 View logs folder" \
      11 "📚 Generate Project Documentation" \
      12 "🏗️ Infrastructure" \
      13 "🔁 Workflows" \
      0 "🚪 Exit"

    [[ -n "${choice}" ]] || break

    case "${choice}" in
      1) "${REPO_ROOT}/scripts/core/dev-auth.sh" ;;
      2) bootstrap_dev_server_menu ;;
      3) proxmox_configure_menu ;;
      4) proxmox_templates_download_menu ;;
      5) proxmox_servers_create_menu ;;
      6) proxmox_servers_destroy_menu ;;
      7) ansible_menu ;;
      8) mikrotik_menu ;;
      9) debug_menu ;;
      10) action_open_logs_folder ;;
      11) documentation_menu ;;
      12) infrastructure_menu ;;
      13) workflows_menu ;;
      0) break ;;
      *) break ;;
    esac
  done

  ui_exit
}
