#!/usr/bin/env bash

MENU_TITLE="System Menu"
MENU_PROMPT="System actions"

declare -A MENU_ITEMS=(
    [1]="Show uptime"
    [2]="Show disk usage"
    [0]="Back"
)

declare -A MENU_ACTIONS=(
    [1]="uptime"
    [2]="df -h"
    [0]="run_menu \"$BASE_DIR/menus/main.menu.sh\""
)

MENU_DEFAULT_ACTION="true"
