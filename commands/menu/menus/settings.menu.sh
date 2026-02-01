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

declare -A MENU_ITEMS=(
    [1]="View current settings"
    [2]="Theme (Catppuccin flavour)"
    [3]="Logging (log level)"
    [4]="UI mode (auto/dialog/text/noninteractive)"
    [5]="Dialog widget defaults"
    [6]="Repo root override"
    [7]="Config file locations"
    [0]="Back"
)

declare -A MENU_ACTIONS=(
    [1]="settings_view_current"
    [2]="settings_change_theme"
    [3]="settings_change_log_level"
    [4]="settings_change_ui_mode"
    [5]="settings_change_dialog_widget_defaults"
    [6]="settings_change_repo_root"
    [7]="settings_show_config_sources"
    [0]="run_menu \"$MENU_DIR/main.menu.sh\""
)

MENU_DEFAULT_ACTION="true"
