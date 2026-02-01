#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/lib/settings_ui.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description:
#   Interactive settings screens for the menu, backed by lib/config.sh.
#
# Notes:
#   - Supports dialog and text UI modes.
#   - Writes to the effective config file (system when root; user when not).
# -----------------------------------------------------------------------------

# Guardrail
if [[ -n "${_HOMELAB_SETTINGS_UI_SOURCED:-}" ]]; then
  return 0
fi
readonly _HOMELAB_SETTINGS_UI_SOURCED="1"

_settings_write_path() {
  homelab_config_effective_write_path
}

_settings_show() {
  local title="$1" body="$2"

  if [[ "${UI_MODE:-text}" == "dialog" ]]; then
    dlg msgbox --title "$title" --intent info -- "$body"
  else
    echo
    echo "$title"
    echo "$body"
    echo
    read -r -p "Press Enter to continue..." _ </dev/tty 2>/dev/null || true
  fi
}

settings_current_summary() {
  cat <<EOF
Write target: $(_settings_write_path)

Theme (CATPPUCCIN_FLAVOUR): ${CATPPUCCIN_FLAVOUR:-MOCHA}
UI mode (FORCE_UI_MODE):   ${FORCE_UI_MODE:-<auto>}
Log level (LOG_LEVEL):     ${LOG_LEVEL:-INFO}
Repo override:             ${HOMELAB_REPO_ROOT:-<none>}
Log file:                  ${HOMELAB_LOG_FILE:-<default>}

Dialog screen:             BG=${DIALOG_SCREEN_BG:-<auto>} FG=${DIALOG_SCREEN_FG:-<auto>}
Dialog box:                BG=${DIALOG_DIALOG_BG:-<auto>} FG=${DIALOG_DIALOG_FG:-<auto>}
Dialog shadow:             ${DIALOG_USE_SHADOW:-OFF}
EOF
}

settings_view_current() {
  local body
  body="$(settings_current_summary)"
  _settings_show "Current settings" "$body"
}

settings_change_theme() {
  local current="${CATPPUCCIN_FLAVOUR:-MOCHA}"
  local choice=""

  if [[ "${UI_MODE:-text}" == "dialog" ]]; then
    choice="$(
      dlg radiolist --title "Theme" --intent normal \
        --height 15 --width 70 --list-height 6 -- \
        "Select your Catppuccin flavour" \
        "LATTE" "Light" $( [[ "$current" == "LATTE" ]] && echo "on" || echo "off" ) \
        "FRAPPE" "Mid" $( [[ "$current" == "FRAPPE" ]] && echo "on" || echo "off" ) \
        "MACCHIATO" "Dark" $( [[ "$current" == "MACCHIATO" ]] && echo "on" || echo "off" ) \
        "MOCHA" "Darkest" $( [[ "$current" == "MOCHA" ]] && echo "on" || echo "off" )
    )" || return 0
  else
    echo "Current: $current"
    echo "Options: LATTE, FRAPPE, MACCHIATO, MOCHA"
    read -r -p "Enter new flavour: " choice
  fi

  choice="${choice^^}"
  [[ "$choice" == "FRAPPÉ" ]] && choice="FRAPPE"
  case "$choice" in
    LATTE|FRAPPE|MACCHIATO|MOCHA) ;;
    *) _settings_show "Theme" "Invalid choice. No change made."; return 0 ;;
  esac

  homelab_config_set_kv "CATPPUCCIN_FLAVOUR" "$choice"
  export CATPPUCCIN_FLAVOUR="$choice"

  _settings_show "Theme" "Updated theme to $choice\n\nTakes effect immediately for new screens."
}

settings_change_log_level() {
  local current="${LOG_LEVEL:-INFO}"
  local choice=""

  if [[ "${UI_MODE:-text}" == "dialog" ]]; then
    choice="$(
      dlg radiolist --title "Logging" --intent info \
        --height 15 --width 70 --list-height 6 -- \
        "Select the default log level" \
        "DEBUG" "Full command output" $( [[ "$current" == "DEBUG" ]] && echo "on" || echo "off" ) \
        "INFO" "Normal" $( [[ "$current" == "INFO" ]] && echo "on" || echo "off" ) \
        "WARN" "Warnings and errors" $( [[ "$current" == "WARN" ]] && echo "on" || echo "off" ) \
        "ERROR" "Errors only" $( [[ "$current" == "ERROR" ]] && echo "on" || echo "off" )
    )" || return 0
  else
    echo "Current: $current"
    echo "Options: DEBUG, INFO, WARN, ERROR"
    read -r -p "Enter new log level: " choice
  fi

  choice="${choice^^}"
  case "$choice" in
    DEBUG|INFO|WARN|ERROR) ;;
    *) _settings_show "Logging" "Invalid choice. No change made."; return 0 ;;
  esac

  homelab_config_set_kv "LOG_LEVEL" "$choice"
  export LOG_LEVEL="$choice"
  homelab_log_init

  _settings_show "Logging" "Updated log level to $choice"
}

settings_change_ui_mode() {
  local current="${FORCE_UI_MODE:-}"
  local choice=""

  if [[ "${UI_MODE:-text}" == "dialog" ]]; then
    choice="$(
      dlg radiolist --title "UI mode" --intent normal \
        --height 15 --width 75 --list-height 6 -- \
        "Force the UI mode (leave Auto for best compatibility)" \
        "AUTO" "Auto-detect" $( [[ -z "$current" ]] && echo "on" || echo "off" ) \
        "dialog" "Dialog UI" $( [[ "$current" == "dialog" ]] && echo "on" || echo "off" ) \
        "text" "Text UI" $( [[ "$current" == "text" ]] && echo "on" || echo "off" ) \
        "noninteractive" "Non-interactive" $( [[ "$current" == "noninteractive" ]] && echo "on" || echo "off" )
    )" || return 0
  else
    echo "Current: ${current:-AUTO}"
    echo "Options: AUTO, dialog, text, noninteractive"
    read -r -p "Enter new UI mode: " choice
  fi

  if [[ "${choice^^}" == "AUTO" || -z "$choice" ]]; then
    choice=""
  else
    choice="${choice,,}"
    case "$choice" in
      dialog|text|noninteractive) ;;
      *) _settings_show "UI mode" "Invalid choice. No change made."; return 0 ;;
    esac
  fi

  homelab_config_set_kv "FORCE_UI_MODE" "$choice"
  export FORCE_UI_MODE="$choice"
  _settings_show "UI mode" "Updated FORCE_UI_MODE to ${choice:-<auto>}\n\nTakes effect next time the menu starts."
}

settings_change_repo_root() {
  local current="${HOMELAB_REPO_ROOT:-}"
  local choice=""

  if [[ "${UI_MODE:-text}" == "dialog" ]]; then
    choice="$(dlg inputbox --title "Repo root" --intent warn --height 12 --width 80 -- \
      "Set a repo root override (leave blank to clear).\n\nCurrent: ${current:-<none>}" \
      "$current")" || return 0
  else
    echo "Current: ${current:-<none>}"
    read -r -p "Enter new repo root (blank to clear): " choice
  fi

  # Clear
  if [[ -z "$choice" ]]; then
    homelab_config_set_kv "HOMELAB_REPO_ROOT" ""
    export HOMELAB_REPO_ROOT=""
    _settings_show "Repo root" "Cleared repo root override."
    return 0
  fi

  if [[ ! -d "$choice" || ! -e "${choice%/}/.root_marker" ]]; then
    _settings_show "Repo root" "That path doesn't look like a valid repo (missing .root_marker).\n\nNo change made."
    return 0
  fi

  homelab_config_set_kv "HOMELAB_REPO_ROOT" "$choice"
  export HOMELAB_REPO_ROOT="$choice"
  _settings_show "Repo root" "Updated repo root override.\n\nTakes effect next run."
}

settings_change_dialog_widget_defaults() {
  # Generic editor for any supported dialog widget.
  local -a widgets=()
  local k

  # Pull widgets from dialog_api.sh defaults, which is sourced by menu.sh.
  for k in "${!DLG_DEF_H[@]}"; do
    widgets+=("$k")
  done
  IFS=$'\n' widgets=($(sort <<<"${widgets[*]}"))
  unset IFS

  local widget=""
  if [[ "${UI_MODE:-text}" == "dialog" ]]; then
    local -a opts=()
    for k in "${widgets[@]}"; do
      opts+=("$k" "$k")
    done
        local menuh="${#widgets[@]}"
    (( menuh > 12 )) && menuh=12
    (( menuh < 1 )) && menuh=1

    widget="$(dlg menu --title "Dialog defaults" --intent normal --height 20 --width 70 --list-height "$menuh" -- \
      "Choose a widget to set defaults for" \
      "${opts[@]}" \
    )" || return 0
  else
    echo "Widgets: ${widgets[*]}"
    read -r -p "Enter widget name: " widget
  fi

  [[ -z "$widget" ]] && return 0
  widget="${widget,,}"

  # Current values (from env overrides or library defaults)
  local cur_h cur_w cur_l cur_f
  cur_h="$(dlg_default_get "$widget" "H" "${DLG_DEF_H[$widget]:-0}")"
  cur_w="$(dlg_default_get "$widget" "W" "${DLG_DEF_W[$widget]:-0}")"
  cur_l="$(dlg_default_get "$widget" "LISTH" "${DLG_DEF_LISTH[$widget]:-0}")"
  cur_f="$(dlg_default_get "$widget" "FORMH" "${DLG_DEF_FORMH[$widget]:-0}")"

  local h w l f
  if [[ "${UI_MODE:-text}" == "dialog" ]]; then
    # form returns newline separated fields
    local out
    out="$(dlg form --title "Defaults: $widget" --intent info --height 18 --width 70 --form-height 0 -- \
      "Set defaults (0 means dialog decides)." \
      "Height" 1 1 "$cur_h" 1 18 8 0 \
      "Width" 2 1 "$cur_w" 2 18 8 0 \
      "ListH" 3 1 "$cur_l" 3 18 8 0 \
      "FormH" 4 1 "$cur_f" 4 18 8 0
    )" || return 0
    IFS=$'\n' read -r h w l f <<<"$out"
    unset IFS
  else
    read -r -p "Height [$cur_h]: " h
    read -r -p "Width  [$cur_w]: " w
    read -r -p "ListH  [$cur_l]: " l
    read -r -p "FormH  [$cur_f]: " f
    h="${h:-$cur_h}"; w="${w:-$cur_w}"; l="${l:-$cur_l}"; f="${f:-$cur_f}"
  fi

  # Basic numeric validation
  for v in "$h" "$w" "$l" "$f"; do
    [[ "$v" =~ ^[0-9]+$ ]] || { _settings_show "Dialog defaults" "All values must be numeric. No change made."; return 0; }
  done

  local up="${widget^^}"
  homelab_config_set_kv "DIALOG_DEFAULT_${up}_H" "$h"
  homelab_config_set_kv "DIALOG_DEFAULT_${up}_W" "$w"
  if [[ -n "${DLG_DEF_LISTH[$widget]:-}" ]]; then
    homelab_config_set_kv "DIALOG_DEFAULT_${up}_LISTH" "$l"
  fi
  if [[ -n "${DLG_DEF_FORMH[$widget]:-}" ]]; then
    homelab_config_set_kv "DIALOG_DEFAULT_${up}_FORMH" "$f"
  fi

  # Export for current run too.
  export "DIALOG_DEFAULT_${up}_H"="$h"
  export "DIALOG_DEFAULT_${up}_W"="$w"
  [[ -n "${DLG_DEF_LISTH[$widget]:-}" ]] && export "DIALOG_DEFAULT_${up}_LISTH"="$l"
  [[ -n "${DLG_DEF_FORMH[$widget]:-}" ]] && export "DIALOG_DEFAULT_${up}_FORMH"="$f"

  _settings_show "Dialog defaults" "Updated defaults for $widget"
}


# -----------------------------------------------------------------------------
# Dialog appearance (background/shadow)
# -----------------------------------------------------------------------------

_settings_colour_options() {
  # Returns a flat list suitable for dialog menu/radiolist:
  # tag item ...
  echo "INHERIT" "Use Catppuccin default"        "BLACK" "Black"        "RED" "Red"        "GREEN" "Green"        "YELLOW" "Yellow"        "BLUE" "Blue"        "MAGENTA" "Magenta"        "CYAN" "Cyan"        "WHITE" "White"
}

_settings_pick_colour() {
  # Usage: _settings_pick_colour "Title" "Prompt" "CURRENT"
  # Returns: "" for INHERIT, else a curses colour name.
  local title="$1" prompt="$2" current="${3:-}"

  local cur="${current^^}"
  [[ -z "$cur" ]] && cur="INHERIT"

  if [[ "${UI_MODE:-text}" == "dialog" ]]; then
    local out
    # radiolist: tag item on/off ...
    out="$(
      dlg radiolist --title "$title" --intent normal         --height 18 --width 72 --list-height 10 --         "$prompt"         "INHERIT" "Use Catppuccin default" $( [[ "$cur" == "INHERIT" ]] && echo "on" || echo "off" )         "BLACK" "Black" $( [[ "$cur" == "BLACK" ]] && echo "on" || echo "off" )         "RED" "Red" $( [[ "$cur" == "RED" ]] && echo "on" || echo "off" )         "GREEN" "Green" $( [[ "$cur" == "GREEN" ]] && echo "on" || echo "off" )         "YELLOW" "Yellow" $( [[ "$cur" == "YELLOW" ]] && echo "on" || echo "off" )         "BLUE" "Blue" $( [[ "$cur" == "BLUE" ]] && echo "on" || echo "off" )         "MAGENTA" "Magenta" $( [[ "$cur" == "MAGENTA" ]] && echo "on" || echo "off" )         "CYAN" "Cyan" $( [[ "$cur" == "CYAN" ]] && echo "on" || echo "off" )         "WHITE" "White" $( [[ "$cur" == "WHITE" ]] && echo "on" || echo "off" )
    )" || return 1
    [[ "$out" == "INHERIT" ]] && out=""
    printf '%s' "$out"
    return 0
  fi

  echo "Current: ${cur}"
  echo "Options: INHERIT, BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE"
  read -r -p "Enter colour: " cur
  cur="${cur^^}"
  [[ "$cur" == "INHERIT" ]] && cur=""
  printf '%s' "$cur"
}

_settings_set_colour_pair() {
  # Usage: _settings_set_colour_pair "Screen" KEY_BG KEY_FG CURRENT_BG CURRENT_FG
  local label="$1" key_bg="$2" key_fg="$3" cur_bg="$4" cur_fg="$5"

  local bg fg
  bg="$(_settings_pick_colour "$label background" "Select ${label,,} background colour" "$cur_bg")" || return 0
  fg="$(_settings_pick_colour "$label text" "Select ${label,,} text (foreground) colour" "$cur_fg")" || return 0

  homelab_config_set_kv "$key_bg" "$bg"
  homelab_config_set_kv "$key_fg" "$fg"
  export "$key_bg"="$bg"
  export "$key_fg"="$fg"

  _settings_show "Dialog appearance" "Updated ${label,,} colours.

BG=${bg:-<auto>} FG=${fg:-<auto>}

Takes effect immediately for new screens."
}

settings_change_dialog_appearance() {
  # Global dialog appearance controls (via DIALOGRC generation).
  # These settings are global; per-menu overrides are set in the menu file itself.
  local choice=""

  while true; do
    local cur_screen_bg="${DIALOG_SCREEN_BG:-}"
    local cur_screen_fg="${DIALOG_SCREEN_FG:-}"
    local cur_dialog_bg="${DIALOG_DIALOG_BG:-}"
    local cur_dialog_fg="${DIALOG_DIALOG_FG:-}"
    local cur_shadow="${DIALOG_USE_SHADOW:-OFF}"

    if [[ "${UI_MODE:-text}" == "dialog" ]]; then
      choice="$(
        dlg menu --title "Dialog appearance" --intent normal           --height 20 --width 78 --list-height 8 --           "Background and shadow settings (global)"           "1" "Screen colours (BG/FG): ${cur_screen_bg:-<auto>}/${cur_screen_fg:-<auto>}"           "2" "Dialog colours (BG/FG): ${cur_dialog_bg:-<auto>}/${cur_dialog_fg:-<auto>}"           "3" "Shadow: ${cur_shadow}"           "4" "Reset colours to Catppuccin defaults"           "0" "Back"
      )" || return 0
    else
      echo
      echo "Dialog appearance"
      echo "1) Screen colours (BG/FG): ${cur_screen_bg:-<auto>}/${cur_screen_fg:-<auto>}"
      echo "2) Dialog colours (BG/FG): ${cur_dialog_bg:-<auto>}/${cur_dialog_fg:-<auto>}"
      echo "3) Shadow: ${cur_shadow}"
      echo "4) Reset colours to Catppuccin defaults"
      echo "0) Back"
      read -r -p "Choose: " choice
    fi

    case "$choice" in
      1)
        _settings_set_colour_pair "Screen" "DIALOG_SCREEN_BG" "DIALOG_SCREEN_FG" "$cur_screen_bg" "$cur_screen_fg"
        ;;
      2)
        _settings_set_colour_pair "Dialog" "DIALOG_DIALOG_BG" "DIALOG_DIALOG_FG" "$cur_dialog_bg" "$cur_dialog_fg"
        ;;
      3)
        local sh
        if [[ "${UI_MODE:-text}" == "dialog" ]]; then
          sh="$(
            dlg radiolist --title "Shadow" --intent normal               --height 12 --width 60 --list-height 4 --               "Enable drop shadow behind dialog boxes?"               "ON" "Enabled" $( [[ "${cur_shadow^^}" == "ON" ]] && echo "on" || echo "off" )               "OFF" "Disabled" $( [[ "${cur_shadow^^}" != "ON" ]] && echo "on" || echo "off" )
          )" || { choice=""; continue; }
        else
          echo "Current: ${cur_shadow}"
          echo "Options: ON, OFF"
          read -r -p "Enter: " sh
        fi

        sh="${sh^^}"
        case "$sh" in
          ON|OFF) ;;
          *) _settings_show "Shadow" "Invalid choice. No change made."; continue ;;
        esac

        homelab_config_set_kv "DIALOG_USE_SHADOW" "$sh"
        export DIALOG_USE_SHADOW="$sh"
        _settings_show "Shadow" "Updated shadow to ${sh}"
        ;;
      4)
        homelab_config_set_kv "DIALOG_SCREEN_BG" ""
        homelab_config_set_kv "DIALOG_SCREEN_FG" ""
        homelab_config_set_kv "DIALOG_DIALOG_BG" ""
        homelab_config_set_kv "DIALOG_DIALOG_FG" ""
        export DIALOG_SCREEN_BG="" DIALOG_SCREEN_FG="" DIALOG_DIALOG_BG="" DIALOG_DIALOG_FG=""
        _settings_show "Dialog appearance" "Reset colours to Catppuccin defaults.

Takes effect immediately for new screens."
        ;;
      0|"")
        return 0
        ;;
      *)
        _settings_show "Dialog appearance" "Unknown option."
        ;;
    esac
  done
}

settings_show_config_sources() {
  _settings_show "Config files" "$(homelab_config_effective_source_summary)"
}
