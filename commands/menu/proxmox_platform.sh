#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/proxmox_platform.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Proxmox platform submenu.
# Purpose:
#   Provide a focused submenu for Proxmox foundation tasks (access, tokens,
#   and template management). These actions typically prepare the platform for
#   workload provisioning.
#
# Usage:
#   Source from commands/menu.sh and call: menu_proxmox_platform
#
# Notes:
#   - This file is sourced by commands/menu.sh. It must not execute code at
#     import time (only define functions).
#   - The underlying command implementations may be placeholders depending on
#     current sprint scope.
# -----------------------------------------------------------------------------

set -Eeuo pipefail

menu_proxmox_platform() {
  local choice

  while true; do
    choice="$(ui_menu "@proxmox" "Proxmox platform" "Choose an option" \
      "proxmox_access" "Proxmox users, roles and tokens" \
      "templates" "Download and manage templates" \
      "back" "Back")"

    case "${choice}" in
      proxmox_access)
        log_section "Proxmox platform: access" || true
        proxmox_access_impl || true
        ;;
      templates)
        log_section "Proxmox platform: templates" || true
        templates_impl || true
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
