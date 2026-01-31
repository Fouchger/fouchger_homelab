#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/workloads_servers.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Workloads and servers submenu.
# Purpose:
#   Provide a focused submenu for workload lifecycle tasks, including
#   provisioning via Terraform and configuration via Ansible, plus app
#   installation and removal based on selections.
#
# Usage:
#   Source from commands/menu.sh and call: menu_workloads_servers
#
# Notes:
#   - This file is sourced by commands/menu.sh. It must not execute code at
#     import time (only define functions).
#   - Some underlying commands may be placeholders depending on sprint scope.
# -----------------------------------------------------------------------------

set -Eeuo pipefail

menu_workloads_servers() {
  local choice

  while true; do
    choice="$(ui_menu "@workloads" "Workloads and servers" "Choose an option" \
      "terraform_apply" "Provision LXC/VM with Terraform" \
      "ansible_apply" "Configure with Ansible" \
      "apps_install" "Install selected apps" \
      "apps_uninstall" "Uninstall selected apps" \
      "cleanup" "Cleanup (danger zone)" \
      "back" "Back")"

    case "${choice}" in
      terraform_apply)
        log_section "Workloads: terraform_apply" || true
        terraform_apply_impl || true
        ;;
      ansible_apply)
        log_section "Workloads: ansible_apply" || true
        ansible_apply_impl || true
        ;;
      apps_install)
        log_section "Workloads: apps_install" || true
        apps_install_impl || true
        ;;
      apps_uninstall)
        log_section "Workloads: apps_uninstall" || true
        apps_uninstall_impl || true
        ;;
      cleanup)
        log_section "Workloads: cleanup" || true
        cleanup_impl || true
        ;;
      back|"")
        break
        ;;
      *)
        ui_warn "Unknown option" "Selection not recognised: ${choice}" || true
        ;;
    esac
  done

  return 0
}
