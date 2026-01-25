#!/usr/bin/env bash
# =============================================================================
# Filename: lib/ui.sh
# Description: Standard dialog-only UI layer for fouchger_homelab
#
# Purpose
#   Provide consistent menus, sub-menus, and questionnaires using dialog only.
#
# Behaviour contract
#   - Cancel/Esc returns 0 and sets output variables to empty string.
#   - No whiptail/plain fallback. If dialog is missing, we install it (Debian/Ubuntu)
#     or fail with a clear message.
#
# UX defaults
#   - Mouse enabled
#   - Spacebar toggles items in checklists (dialog default)
# =============================================================================
echo "lib/ui.sh"
set -Eeuo pipefail
IFS=$'\n\t'

# Defaults (can be overridden by caller env vars)
: "${UI_MENU_HEIGHT:=20}"
: "${UI_MENU_WIDTH:=95}"
: "${UI_MENU_LIST_HEIGHT:=12}"

: "${UI_CHECK_HEIGHT:=22}"
: "${UI_CHECK_WIDTH:=110}"
: "${UI_CHECK_LIST_HEIGHT:=16}"

: "${UI_MSG_HEIGHT:=12}"
: "${UI_MSG_WIDTH:=80}"

# Menu runtime state (temp files, rc files, etc.). Prefer the repo-defined UI_DIR
# from lib/paths.sh so all operational artefacts are managed by ensure_dirs().
: "${UI_STATE_DIR:=${UI_DIR:-${STATE_DIR:-${STATE_DIR_DEFAULT:-$HOME/.config/fouchger_homelab/state}}/ui}}"

ui_init() {
  # Ensure standard directories exist (logs/state/ui), if available.
  if declare -F ensure_dirs >/dev/null 2>&1; then
    ensure_dirs >/dev/null 2>&1 || true
  else
    mkdir -p "${UI_STATE_DIR}" >/dev/null 2>&1 || true
  fi
  export TERM="${TERM:-xterm-256color}"

  # Ensure consistent look and feel:
  # - mouse enabled
  # - avoid conflicting options if user sets DIALOGOPTS externally
  if [[ "${DIALOGOPTS:-}" != *"--mouse"* && "${DIALOGOPTS:-}" != *"--no-mouse"* ]]; then
    export DIALOGOPTS="${DIALOGOPTS:-} --mouse"
  fi

  ui_ensure_dialog
}

ui_ensure_dialog() {
  command -v dialog >/dev/null 2>&1 && return 0

  # Best-effort install on Debian/Ubuntu. Uses apt_install if available.
  if command -v apt_install >/dev/null 2>&1; then
    apt_install dialog
  elif command -v apt-get >/dev/null 2>&1; then
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
      apt-get update -y
      apt-get install -y --no-install-recommends dialog
    elif command -v sudo >/dev/null 2>&1; then
      sudo apt-get update -y
      sudo apt-get install -y --no-install-recommends dialog
    fi
  fi

  command -v dialog >/dev/null 2>&1 || {
    echo "ERROR: 'dialog' is required but not available." >&2
    echo "Install it with: sudo apt-get update && sudo apt-get install -y dialog" >&2
    exit 1
  }
}

ui_tmpfile() {
  ui_init
  mktemp "${UI_STATE_DIR}/.${1}.XXXXXX"
}

ui_run() {
  # Read from /dev/tty when possible for reliability under make/redirects
  if [[ -r /dev/tty && -w /dev/tty ]]; then
    dialog "$@" </dev/tty
  else
    dialog "$@"
  fi
}

ui_msgbox() {
  local title="$1" msg="$2"
  ui_init
  ui_run --clear --title "${title}" --msgbox "${msg}" "${UI_MSG_HEIGHT}" "${UI_MSG_WIDTH}" || true
}

ui_confirm() {
  # Returns: 0 yes, 1 no/cancel
  local title="$1" prompt="$2"
  ui_init
  ui_run --clear --title "${title}" --yesno "${prompt}" "${UI_MSG_HEIGHT}" "${UI_MSG_WIDTH}"
}

ui_input() {
  # Usage: ui_input "Title" "Prompt" outvar [default]
  # Cancel/Esc returns 0 and outvar=""
  local title="$1" prompt="$2" outvar="$3" def="${4:-}"
  printf -v "${outvar}" '%s' ""
  ui_init

  local tmp
  tmp="$(ui_tmpfile input)"
  if ! ui_run --clear --title "${title}" --inputbox "${prompt}" 12 85 "${def}" 2>"${tmp}"; then
    rm -f -- "${tmp}" || true
    return 0
  fi

  printf -v "${outvar}" '%s' "$(cat "${tmp}" 2>/dev/null || true)"
  rm -f -- "${tmp}" || true
  return 0
}

ui_menu() {
  # Usage: ui_menu "Title" "Prompt" outvar key1 label1 key2 label2 ...
  # Cancel/Esc returns 0 and outvar=""
  local title="$1" prompt="$2" outvar="$3"
  shift 3
  printf -v "${outvar}" '%s' ""
  ui_init

  local tmp
  tmp="$(ui_tmpfile menu)"
  if ! ui_run --clear --title "${title}" \
    --menu "${prompt}" "${UI_MENU_HEIGHT}" "${UI_MENU_WIDTH}" "${UI_MENU_LIST_HEIGHT}" \
    "$@" 2>"${tmp}"; then
    rm -f -- "${tmp}" || true
    return 0
  fi

  printf -v "${outvar}" '%s' "$(cat "${tmp}" 2>/dev/null || true)"
  rm -f -- "${tmp}" || true
  return 0
}

ui_checklist() {
  # Usage: ui_checklist "Title" "Prompt" outvar key label on/off ...
  # Cancel/Esc returns 0 and outvar=""
  # Space toggles selection (dialog default). Mouse works too.
  local title="$1" prompt="$2" outvar="$3"
  shift 3
  printf -v "${outvar}" '%s' ""
  ui_init

  local tmp
  tmp="$(ui_tmpfile checklist)"
  if ! ui_run --clear --title "${title}" \
    --checklist "${prompt}" "${UI_CHECK_HEIGHT}" "${UI_CHECK_WIDTH}" "${UI_CHECK_LIST_HEIGHT}" \
    "$@" 2>"${tmp}"; then
    rm -f -- "${tmp}" || true
    return 0
  fi

  # dialog returns quoted values
  local raw
  raw="$(tr -d '"' <"${tmp}" 2>/dev/null || true)"
  printf -v "${outvar}" '%s' "${raw}"
  rm -f -- "${tmp}" || true
  return 0
}

ui_exit() {
  # Clear the screen to avoid leaving dialog artefacts behind
  clear || true
}

ui_placeholder() {
  local title="${1:-Feature unavailable}"
  local message="${2:-This capability is not yet implemented in this release.}"

  if command -v dialog >/dev/null 2>&1; then
    dialog --title "$title" \
           --msgbox "$message\n\nPlease check back in a future release." 8 60
  else
    printf '%s\n' "[$title] $message" >&2
  fi
}

# =============================================================================
# Function: ui_textbox
# Created : 2026-01-24
# Purpose : Display a scrollable text file in a large dialog textbox.
#
# Notes:
# - Uses dialog --textbox with --scrollbar for long reports.
# - Sizes the box to ~90% of terminal dimensions (with sane minimums).
# - Requires dialog to be installed and $DIALOG_BIN / dialog available.
# =============================================================================
ui_textbox() {
  local title="${1:-Output}"
  local file="${2:-}"

  if [[ -z "${file}" || ! -f "${file}" ]]; then
    ui_msgbox "Error" "ui_textbox: file not found: ${file}"
    return 0
  fi

  # Determine dialog binary (aligns with most ui.sh patterns)
  local dlg="${DIALOG_BIN:-dialog}"
  if ! command -v "${dlg}" >/dev/null 2>&1; then
    echo "ui_textbox: dialog not found" >&2
    return 1
  fi

  # Terminal sizing (fallbacks included)
  local lines cols height width
  lines="$(tput lines 2>/dev/null || echo 24)"
  cols="$(tput cols 2>/dev/null || echo 80)"

  # Use ~90% of available space
  height=$(( lines - 4 ))
  width=$(( cols - 6 ))

  # Sane minimums so it remains usable on small consoles
  (( height < 15 )) && height=15
  (( width < 60 )) && width=60

  # dialog textbox supports scrolling with arrow keys/PageUp/PageDown; scrollbar shows position.
  # --no-collapse keeps formatting, --cr-wrap wraps long lines for readability.
  "${dlg}" \
    --backtitle "${UI_BACKTITLE:-fouchger_homelab}" \
    --title "${title}" \
    --scrollbar \
    --no-collapse \
    --cr-wrap \
    --textbox "${file}" "${height}" "${width}"
}

# =============================================================================
# Function: ui_programbox
# Created : 2026-01-25
# Purpose : Stream live command output inside dialog, giving visible progress.
#
# Notes:
# - Uses dialog --programbox so operators see continuous output.
# - Wraps the command in bash -lc for predictable PATH/expansion.
# - Captures the command exit code to a provided file when requested.
# =============================================================================
ui_programbox() {
  local title="${1:-Running}"; shift || true
  local cmd="${1:-}"; shift || true
  local rc_file="${1:-}"

  ui_init

  if [[ -z "${cmd}" ]]; then
    ui_msgbox "Error" "ui_programbox: no command provided"
    return 0
  fi

  # Determine dialog binary
  local dlg="${DIALOG_BIN:-dialog}"
  command -v "${dlg}" >/dev/null 2>&1 || {
    echo "ui_programbox: dialog not found" >&2
    return 1
  }

  # Terminal sizing (fallbacks included)
  local lines cols height width
  lines="$(tput lines 2>/dev/null || echo 24)"
  cols="$(tput cols 2>/dev/null || echo 80)"
  height=$(( lines - 4 ))
  width=$(( cols - 6 ))
  (( height < 15 )) && height=15
  (( width < 60 )) && width=60

  # If rc_file is set, write the command exit code there for the caller.
  local wrapped
  if [[ -n "${rc_file}" ]]; then
    wrapped="${cmd}; rc=\$?; printf '%s' \"\$rc\" >\"${rc_file}\"; exit \$rc"
  else
    wrapped="${cmd}"
  fi

  # Use --prgbox so the command is executed as a real program (args separated)
  # and the UI does not render the command string as content.
  ui_run --clear \
    --backtitle "${UI_BACKTITLE:-fouchger_homelab}" \
    --title "${title}" \
    --prgbox "Running..." \
    "${height}" "${width}" \
    bash -lc "${wrapped}" || true
}
