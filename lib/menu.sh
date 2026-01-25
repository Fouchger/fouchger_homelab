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

#------------------------
# Main Menu Option:   4 "📦 Download Proxmox templates"
#------------------------
proxmox_templates_download_menu() {
  while true; do
    local choice=""
    ui_menu "📦 Download Proxmox templates" "Choose an action:" choice \
      1 "📦 LXC Ubuntu 24.04" \
      2 "📦 VM Ubuntu 24.04" \
      3 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) download_lxc_ubuntu2404 ;;
      2) download_vm_ubuntu2404 ;;
      3) return 0 ;;
      *) return 0 ;;
    esac
  done
}

#------------------------
# Main Menu Option:   5 "🏗️  Provision or update VMs/LXCs (Terraform apply)"
#------------------------
proxmox_servers_create_menu() {
  while true; do
    local choice=""
    ui_menu "🏗️  Provision or update VMs/LXCs (Terraform apply)" "Choose an action:" choice \
      1 "🏗️ LXC Ubuntu 24.04" \
      2 "🏗️ VM Ubuntu 24.04" \
      3 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1) create_lxc_ubuntu2404 ;;
      2) create_vm_ubuntu2404 ;;
      3) return 0 ;;
      *) return 0 ;;
    esac
  done
}

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

#------------------------
# Main Menu Option:   9 "Debug"
#------------------------
debug_menu() {
  while true; do
    local choice=""
    ui_menu "🐞 Debug" "Diagnostics and troubleshooting tools:" choice \
      1 "🎥 Session capture: Enable" \
      2 "🛑 Session capture: Disable" \
      3 "📋 Session capture: Status" \
      4 "📜 Session capture: Show last 200 lines" \
      5 "📡 Session capture: Live tail (Ctrl+C to exit)" \
      6 "🔙 Back"

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
