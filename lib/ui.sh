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

: "${UI_STATE_DIR:=/tmp/fouchger_homelab_ui}"

ui_init() {
  mkdir -p "${UI_STATE_DIR}" >/dev/null 2>&1 || true
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
