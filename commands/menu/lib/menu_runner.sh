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

    # Optional per-menu theme override (useful for special-purpose screens).
    # If not set, the global CATPPUCCIN_FLAVOUR applies.
    local __saved_catppuccin_flavour="${CATPPUCCIN_FLAVOUR:-}"

    # Reset menu variables to avoid bleed between menus.
    unset MENU_TITLE MENU_PROMPT MENU_DEFAULT_ACTION MENU_DIALOG_INTENT \
      MENU_DIALOG_HEIGHT MENU_DIALOG_WIDTH MENU_DIALOG_LIST_HEIGHT
    unset MENU_ITEMS MENU_ACTIONS

    # Menu definition files are trusted repo files.
    # shellcheck disable=SC1090
    source "$menu_file"

    : "${MENU_TITLE:?menu missing MENU_TITLE ($menu_file)}"
    : "${MENU_PROMPT:?menu missing MENU_PROMPT ($menu_file)}"
    : "${MENU_ITEMS:?menu missing MENU_ITEMS ($menu_file)}"
    : "${MENU_ACTIONS:?menu missing MENU_ACTIONS ($menu_file)}"

    if [[ -n "${MENU_CATPPUCCIN_FLAVOUR:-}" ]]; then
      CATPPUCCIN_FLAVOUR="$MENU_CATPPUCCIN_FLAVOUR"
    fi

    # Run the current menu in a loop so "call|..." actions return to the menu
    # rather than dropping back to the shell. A menu can request returning to
    # its caller by dispatching "back" (or by the user pressing ESC/Cancel).
    while true; do
      local st=0
      case "$UI_MODE" in
          dialog) run_dialog_menu; st=$? ;;
          text)   run_text_menu;   st=$? ;;
          *)      run_noninteractive; st=$? ;;
      esac

      # 200 is a special "back" signal.
      if (( st == 200 )); then
        CATPPUCCIN_FLAVOUR="$__saved_catppuccin_flavour"
        return 0
      fi
    done
}

menu__contrast_fg() {
  # Best-effort readable foreground for a given (curses) background.
  local bg="${1^^}"
  case "$bg" in
    YELLOW|WHITE|CYAN) echo "BLACK" ;;
    *) echo "WHITE" ;;
  esac
}

menu__dispatch_action() {
  # Dispatch without eval (avoids bash errexit+eval edge cases and is safer).
  # Action formats:
  #   menu|/path/to/menu.file
  #   call|function_name|arg1|arg2|...
  #   exit|0
  #   noop
  local action="${1:-}"
  [[ -n "$action" ]] || return 0

  local kind
  local -a parts=()
  local IFS='|'
  read -r -a parts <<<"$action"
  kind="${parts[0]:-}"

  case "$kind" in
    menu)
      run_menu "${parts[1]:-}"
      ;;
    call)
      local fn="${parts[1]:-}"
      if [[ -z "$fn" || -z "$(declare -F "$fn" 2>/dev/null)" ]]; then
        if declare -F log_error >/dev/null 2>&1; then
          log_error "Menu action refers to missing function: $fn"
        else
          echo "[ERROR] Menu action refers to missing function: $fn" >&2
        fi
        return 1
      fi
      "$fn" "${parts[@]:2}"
      ;;
    exit)
      exit "${parts[1]:-0}"
      ;;
    back|return)
      # Signal to the menu loop that we should return to the caller.
      return 200
      ;;
    cmd)
      # Execute an external command safely (no eval). Output behaviour follows
      # the current LOG_LEVEL, if the logging library is loaded.
      if declare -F homelab_run_cmd >/dev/null 2>&1; then
        homelab_run_cmd "Command" "${parts[@]:1}"
      else
        "${parts[@]:1}"
      fi
      ;;
    noop)
      return 0
      ;;
    *)
      # Back-compat: allow bare function names.
      if [[ -n "$(declare -F "$action" 2>/dev/null)" ]]; then
        "$action"
        return $?
      fi
      if declare -F log_error >/dev/null 2>&1; then
        log_error "Unsupported menu action format: $action"
      else
        echo "[ERROR] Unsupported menu action format: $action" >&2
      fi
      return 2
      ;;
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

    local -a dlg_opts=(
      --title "$MENU_TITLE"
      --intent "${MENU_DIALOG_INTENT:-normal}"
    )
    [[ -n "${MENU_DIALOG_HEIGHT:-}" ]] && dlg_opts+=(--height "$MENU_DIALOG_HEIGHT")
    [[ -n "${MENU_DIALOG_WIDTH:-}"  ]] && dlg_opts+=(--width "$MENU_DIALOG_WIDTH")
    [[ -n "${MENU_DIALOG_LIST_HEIGHT:-}" ]] && dlg_opts+=(--list-height "$MENU_DIALOG_LIST_HEIGHT")

    # Optional per-menu background overrides.
    # These are useful if one menu (e.g. Settings) should look different.
    if [[ -n "${MENU_DIALOG_SCREEN_BG:-}" || -n "${MENU_DIALOG_SCREEN_FG:-}" ]]; then
      local sb sf
      sb="$(dlg_color_name "${MENU_DIALOG_SCREEN_BG:-BLACK}")"
      sf="$(dlg_color_name "${MENU_DIALOG_SCREEN_FG:-$(menu__contrast_fg "$sb")}")"
      dlg_opts+=(--rc-set "screen_color=($sf,$sb,OFF)")
    fi

    if [[ -n "${MENU_DIALOG_BG:-}" || -n "${MENU_DIALOG_FG:-}" ]]; then
      local db df
      db="$(dlg_color_name "${MENU_DIALOG_BG:-BLACK}")"
      df="$(dlg_color_name "${MENU_DIALOG_FG:-WHITE}")"
      dlg_opts+=(--rc-set "dialog_color=($df,$db,OFF)")
      # Keep related surfaces consistent
      dlg_opts+=(--rc-set "menubox_color=dialog_color" --rc-set "item_color=dialog_color" --rc-set "check_color=dialog_color")
    fi

    local choice
    choice="$(dlg menu "${dlg_opts[@]}" -- "$MENU_PROMPT" "${options[@]}")"
    local st=$?

    # ESC/Cancel -> back to caller
    if (( st != 0 )); then
      return 200
    fi

    menu__dispatch_action "${MENU_ACTIONS[$choice]:-}"
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
  read -r choice || return 200
  [[ -z "${choice:-}" ]] && return 200
  menu__dispatch_action "${MENU_ACTIONS[$choice]:-}"
}


run_noninteractive() {
    log "Non-interactive mode detected"
    menu__dispatch_action "${MENU_DEFAULT_ACTION:-noop}"
}
