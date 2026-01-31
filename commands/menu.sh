#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Command entrypoint (menu).
# Purpose: Implements one discrete action invoked by homelab.sh or the menu.
# Usage:
#   ./commands/menu.sh
#   ./commands/menu.sh --action diagnostics
#   HOMELAB_DEFAULT_CHOICE=diagnostics ./commands/menu.sh   (headless default)
# Prerequisites:
#   - Project bootstrapped (see bootstrap.sh)
# Notes:
#   - Menu is structured into three operational layers:
#       1) Admin node and bootstrap
#       2) Proxmox platform
#       3) Workloads and servers
#   - Each submenu lives in commands/menu/*.sh for maintainability.
#   - This script follows the command runner contract in lib/command_runner.sh.
#   - Works across Proxmox LXC/VM contexts where /dev/tty or TERM may be absent.
# -----------------------------------------------------------------------------

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/command_runner.sh"

menu_impl() {
  # Main menu loop.
  # This command owns the interactive experience for the current run.

  # Source command implementations so we can call them within the same runtime.
  # Each command script must be guarded so it doesn't execute main when sourced.
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/diagnostics.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/profiles.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/selections.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/apps_install.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/apps_uninstall.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/proxmox_access.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/templates.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/terraform_apply.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/ansible_apply.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/cleanup.sh"

  # Source submenu modules.
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/menu/admin_node.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/menu/proxmox_platform.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/commands/menu/workloads_servers.sh"

  # Optional single-action routing for automation/headless runs.
  # Supported tags: admin_node, proxmox, workloads, diagnostics, exit
  local action=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --action)
        action="${2:-}"
        shift 2
        ;;
      --noninteractive)
        # Convenience flag: forces UI to avoid dialog/text prompts.
        export HOMELAB_UI_MODE="console"
        shift
        ;;
      -h|--help)
        ui_info "Menu help" "Options:\n  --action <admin_node|proxmox|workloads|diagnostics|exit>\n  --noninteractive\n\nEnvironment:\n  HOMELAB_DEFAULT_CHOICE=<same as --action>\n  HOMELAB_UI_MODE=auto|dialog|plain|console"
        return 0
        ;;
      *)
        # Preserve forward compatibility: ignore unknown args but log.
        log_warn "menu: ignoring unknown argument: $1" || true
        shift
        ;;
    esac
  done

  if [[ -n "${action}" ]]; then
    case "${action}" in
      admin_node)
        log_section "Menu: admin_node (action)" || true
        menu_admin_node || true
        runtime_summary_line "menu action completed: admin_node" || true
        return 0
        ;;
      proxmox)
        log_section "Menu: proxmox (action)" || true
        menu_proxmox_platform || true
        runtime_summary_line "menu action completed: proxmox" || true
        return 0
        ;;
      workloads)
        log_section "Menu: workloads (action)" || true
        menu_workloads_servers || true
        runtime_summary_line "menu action completed: workloads" || true
        return 0
        ;;
      diagnostics)
        log_section "Menu: diagnostics (action)" || true
        diagnostics_impl || true
        runtime_summary_line "menu action completed: diagnostics" || true
        return 0
        ;;
      exit)
        log_info "Menu action exit selected" || true
        runtime_summary_line "menu action completed: exit" || true
        return 0
        ;;
      *)
        ui_warn "Unknown action" "Action not recognised: ${action}" || true
        runtime_summary_line "menu action failed: unknown action" || true
        return 0
        ;;
    esac
  fi

  ui_info "@welcome" "fouchger_homelab" "Welcome. Choose a layer to manage: Admin node, Proxmox platform, or Workloads."

  # If UI is fully headless, ui_menu will return HOMELAB_DEFAULT_CHOICE (or empty).
  local choice
  while true; do
    choice="$(ui_menu "@main" "Main menu" "Choose a layer" \
      "admin_node" "Admin node and bootstrap" \
      "proxmox" "Proxmox platform" \
      "workloads" "Workloads and servers" \
      "diagnostics" "Diagnostics" \
      "exit" "Exit")"

    case "${choice}" in
      admin_node)
        log_section "Menu: admin_node" || true
        menu_admin_node || true
        ;;
      proxmox)
        log_section "Menu: proxmox" || true
        menu_proxmox_platform || true
        ;;
      workloads)
        log_section "Menu: workloads" || true
        menu_workloads_servers || true
        ;;
      diagnostics)
        log_section "Menu: diagnostics" || true
        diagnostics_impl || true
        ;;
      exit|"")
        log_info "Menu exit selected" || true
        break
        ;;
      *)
        ui_warn "Unknown option" "Selection not recognised: ${choice}" || true
        ;;
    esac
  done

  runtime_summary_line "menu completed" || true
  return 0
}

main() {
  command_run "menu" menu_impl "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
