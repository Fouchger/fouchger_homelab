#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/admin_node.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Admin node and bootstrap submenu.
# Purpose:
#   Provide a focused submenu for tasks that run on the admin node (the machine
#   executing homelab.sh). This keeps navigation aligned to the three-layer
#   operating model used by this project.
#
# Usage:
#   Source from commands/menu.sh and call: menu_admin_node
#
# Notes:
#   - This file is sourced by commands/menu.sh. It must not execute code at
#     import time (only define functions).
#   - Menu rendering is done via lib/ui_dialog.sh helpers (ui_menu/ui_info).
# -----------------------------------------------------------------------------

set -Eeuo pipefail

menu_admin_node() {
  local choice

  while true; do
    choice="$(ui_menu "@admin_node" "Admin node and bootstrap" "Choose an option" \
      "profiles" "Select profile" \
      "selections" "Manual app selection" \
      "back" "Back")"

    case "${choice}" in
      profiles)
        log_section "Admin node: profiles" || true
        profiles_impl --tier admin || true
        ;;
      selections)
        log_section "Admin node: selections" || true
        selections_impl || true
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
