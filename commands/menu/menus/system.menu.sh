#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/menus/system.menu.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: System administration menu definition.
# Notes:
#   - Expects MENU_DIR (set by menu.sh) and run_menu() (from menu_runner.sh).
# -----------------------------------------------------------------------------

MENU_TITLE="System Menu"
MENU_PROMPT="System actions"

declare -A MENU_ITEMS=(
    [1]="Show uptime"
    [2]="Show disk usage"
    [0]="Back"
)

declare -A MENU_ACTIONS=(
    [1]="cmd|uptime"
    [2]="cmd|df|-h"
    [0]="back|0"
)

MENU_DEFAULT_ACTION="noop"
