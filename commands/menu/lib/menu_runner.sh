#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/lib/menu_runner.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description:
#   Generic menu runner supporting dialog, plain text, and non-interactive
#   operation.
# Notes:
#   - Menus are defined in separate files with MENU_TITLE, MENU_PROMPT,
#     MENU_ITEMS, and MENU_ACTIONS.
# -----------------------------------------------------------------------------

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
    local -a keys=()
    local k

    # Ensure stable ordering (associative arrays do not preserve insert order).
    for k in "${!MENU_ITEMS[@]}"; do
      keys+=("$k")
    done
    IFS=$'\n' keys=($(sort -n <<<"${keys[*]}"))
    unset IFS

    for k in "${keys[@]}"; do
      options+=("$k" "${MENU_ITEMS[$k]}")
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

    if [[ -n "${MENU_ACTIONS[$choice]:-}" ]]; then
      eval "${MENU_ACTIONS[$choice]}"
    fi
}

run_text_menu() {
  echo -e "${C_TITLE}${MENU_TITLE}${RESET}"
  echo

  local -a keys=()
  local k
  for k in "${!MENU_ITEMS[@]}"; do
    keys+=("$k")
  done
  IFS=$'\n' keys=($(sort -n <<<"${keys[*]}"))
  unset IFS

  for k in "${keys[@]}"; do
    echo -e "  ${C_KEY}${k})${RESET} ${C_TEXT}${MENU_ITEMS[$k]}${RESET}"
  done

  echo
  echo -ne "${C_PROMPT}Select option:${RESET} "
  read -r choice
  if [[ -n "${MENU_ACTIONS[$choice]:-}" ]]; then
    eval "${MENU_ACTIONS[$choice]}"
  fi
}


run_noninteractive() {
    log "Non-interactive mode detected"
    eval "${MENU_DEFAULT_ACTION:-:}"
}
