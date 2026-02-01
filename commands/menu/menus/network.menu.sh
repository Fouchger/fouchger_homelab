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

declare -A MENU_ITEMS=(
    [1]="Show IP addresses"
    [2]="Show routes"
    [0]="Back"
)

declare -A MENU_ACTIONS=(
    [1]="ip -br addr || ifconfig -a"
    [2]="ip route || netstat -rn"
    [0]="run_menu \"$MENU_DIR/main.menu.sh\""
)

MENU_DEFAULT_ACTION="true"
