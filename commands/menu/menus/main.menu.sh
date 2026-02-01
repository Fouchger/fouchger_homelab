#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/menus/main.menu.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Top-level menu definition.
# Notes:
#   - Expects MENU_DIR (set by menu.sh) and run_menu() (from menu_runner.sh).
# -----------------------------------------------------------------------------

MENU_TITLE="Main Menu"
MENU_PROMPT="Choose an option"

declare -A MENU_ITEMS=(
    [1]="$EMO_SYSTEM System Menu"
    [2]="$EMO_NET Network Menu"
    [3]="⚙️ Settings"
    [0]="$EMO_EXIT Exit"
)

declare -A MENU_ACTIONS=(
    [1]="menu|$MENU_DIR/system.menu.sh"
    [2]="menu|$MENU_DIR/network.menu.sh"
    [3]="menu|$MENU_DIR/settings.menu.sh"
    [0]="exit|0"
)

MENU_DEFAULT_ACTION="exit|0"
