#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/menus/network.menu.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description:
#   Network menu definition (template placeholder).
#
# Notes:
#   - Keep each submenu in its own file for easy maintenance.
#   - Replace commands below with your preferred network tooling.
# -----------------------------------------------------------------------------

MENU_TITLE="Network Menu"
MENU_PROMPT="Network actions"

network_show_ips() {
  if command -v ip >/dev/null 2>&1; then
    ip -br addr
  elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig -a
  else
    echo "No supported network tool found (need iproute2 or net-tools)." >&2
    return 127
  fi
}

network_show_routes() {
  if command -v ip >/dev/null 2>&1; then
    ip route
  elif command -v netstat >/dev/null 2>&1; then
    netstat -rn
  else
    echo "No supported routing tool found (need iproute2 or net-tools)." >&2
    return 127
  fi
}

declare -A MENU_ITEMS=(
    [1]="Show IP addresses"
    [2]="Show routes"
    [0]="Back"
)

declare -A MENU_ACTIONS=(
    [1]="call|network_show_ips"
    [2]="call|network_show_routes"
    [0]="back|0"
)

MENU_DEFAULT_ACTION="noop"
