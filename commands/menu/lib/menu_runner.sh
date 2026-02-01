#!/usr/bin/env bash

run_menu() {
    local menu_file="$1"
    source "$menu_file"

    case "$UI_MODE" in
        dialog) run_dialog_menu ;;
        text)   run_text_menu ;;
        *)      run_noninteractive ;;
    esac
}

run_dialog_menu() {
    local options=()
    for i in "${!MENU_ITEMS[@]}"; do
        options+=("$i" "${MENU_ITEMS[$i]}")
    done

    local choice
    choice="$(
      dlg menu \
        --title "$MENU_TITLE" \
        --intent "${MENU_DIALOG_INTENT:-normal}" \
        --height "${MENU_DIALOG_HEIGHT:-}" \
        --width "${MENU_DIALOG_WIDTH:-}" \
        --list-height "${MENU_DIALOG_LIST_HEIGHT:-}" \
        -- \
        "$MENU_PROMPT" \
        "${options[@]}"
    )" || return

    eval "${MENU_ACTIONS[$choice]}"
}

run_text_menu() {
    echo -e "${C_TITLE}${MENU_TITLE}${RESET}"
    echo

    for i in "${!MENU_ITEMS[@]}"; do
        echo -e "  ${C_KEY}${i})${RESET} ${C_TEXT}${MENU_ITEMS[$i]}${RESET}"
    done

    echo
    echo -ne "${C_PROMPT}Select option:${RESET} "
    read -r choice
    eval "${MENU_ACTIONS[$choice]:-:}"
}


run_noninteractive() {
    log "Non-interactive mode detected"
    eval "${MENU_DEFAULT_ACTION:-:}"
}
