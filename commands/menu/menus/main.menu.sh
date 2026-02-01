#!/usr/bin/env bash

MENU_TITLE="Main Menu"
MENU_PROMPT="Choose an option"

declare -A MENU_ITEMS=(
    [1]="$EMO_SYSTEM System Menu"
    [2]="$EMO_NET Network Menu"
    [0]="$EMO_EXIT Exit"
)

declare -A MENU_ACTIONS=(
    [1]="run_menu \"$BASE_DIR/menus/system.menu.sh\""
    [2]="run_menu \"$BASE_DIR/menus/network.menu.sh\""
    [0]="exit 0"
)

MENU_DEFAULT_ACTION="exit 0"
