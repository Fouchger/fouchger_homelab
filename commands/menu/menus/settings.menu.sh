#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/menus/settings.menu.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description:
#   Settings menu definition (theme, logging, UI mode, defaults).
# Notes:
#   - Expects MENU_DIR (set by menu.sh) and run_menu() (from menu_runner.sh).
#   - Expects settings_* functions (from commands/menu/lib/settings_ui.sh).
# -----------------------------------------------------------------------------

MENU_TITLE="Settings"
MENU_PROMPT="View and update system settings"

# Per-object sizing: Settings screens generally need a bit more space.
MENU_DIALOG_HEIGHT="22"
MENU_DIALOG_WIDTH="86"
MENU_DIALOG_LIST_HEIGHT="12"

# Per-object colours: you can override how this menu looks without affecting
# other menus. These are optional.
# MENU_DIALOG_INTENT can be: normal|info|success|warn|error (or a curses colour).
MENU_DIALOG_INTENT="${MENU_DIALOG_INTENT:-normal}"
# Background overrides (curses colours). Leave blank to inherit Catppuccin defaults.
# MENU_DIALOG_SCREEN_BG="BLACK"; MENU_DIALOG_SCREEN_FG="WHITE"
# MENU_DIALOG_BG="BLACK"; MENU_DIALOG_FG="WHITE"

declare -A MENU_ITEMS=(
    [1]="View current settings"
    [2]="Theme (Catppuccin flavour)"
    [3]="Logging (log level)"
    [4]="UI mode (auto/dialog/text/noninteractive)"
    [5]="Dialog widget defaults"
    [8]="Dialog appearance (background/shadow)"
    [6]="Repo root override"
    [7]="Config file locations"
    [0]="Back"
)

declare -A MENU_ACTIONS=(
    [1]="call|settings_view_current"
    [2]="call|settings_change_theme"
    [3]="call|settings_change_log_level"
    [4]="call|settings_change_ui_mode"
    [5]="call|settings_change_dialog_widget_defaults"
    [8]="call|settings_change_dialog_appearance"
    [6]="call|settings_change_repo_root"
    [7]="call|settings_show_config_sources"
    [0]="back|0"
)

MENU_DEFAULT_ACTION="noop"
