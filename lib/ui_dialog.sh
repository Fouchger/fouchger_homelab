#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/ui_dialog.sh
# Created: 2026-01-30
# Updated: 2026-01-31
#
# Description:
#   Dialog-driven UI helpers with safe fallback to console output.
#
# Purpose:
#   - Provide a stable, public UI helper API used across commands.
#   - Keep a consistent look and feel across interactive and non-interactive runs.
#   - Never terminate the runtime (UI calls are best-effort and return success).
#
# Public API (Sprint 2):
#   ui_init
#   ui_info
#   ui_warn
#   ui_error
#   ui_menu
#
# Usage:
#   source "${ROOT_DIR}/lib/ui_dialog.sh"
#   ui_init
#   ui_info "Hello" "Welcome to fouchger_homelab"
#
# Prerequisites:
#   - bash >= 4
#   - dialog (optional)
#
# Notes:
#   - All functions are safe to call multiple times.
#   - If logger functions exist (log_info/log_warn/log_error), UI helpers will log.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

UI_MODE="console"   # console|dialog
UI_WIDTH=70
UI_HEIGHT=20
UI_BACKTITLE="fouchger_homelab"
UI_INITIALISED=0

ui__has_dialog() {
  command -v dialog >/dev/null 2>&1
}

ui__is_tty() {
  [[ -t 1 ]] && [[ -t 2 ]]
}

ui__log_if_available() {
  # Best-effort bridge into logger.sh if it's loaded.
  # Args: level (info|warn|error), message
  local level msg
  level="${1:-info}"
  msg="${2:-}"

  case "${level}" in
    info)
      if declare -F log_info >/dev/null 2>&1; then log_info "${msg}" || true; fi
      ;;
    warn)
      if declare -F log_warn >/dev/null 2>&1; then log_warn "${msg}" || true; fi
      ;;
    error)
      if declare -F log_error >/dev/null 2>&1; then log_error "${msg}" || true; fi
      ;;
  esac
}

ui_init() {
  # Idempotent initialiser.
  # Determines UI_MODE and sizing, with safe fallbacks for non-interactive contexts.
  if [[ "${UI_INITIALISED}" -eq 1 ]]; then
    return 0
  fi
  UI_INITIALISED=1

  # Determine preferred UI mode.
  # HOMELAB_UI_MODE: auto|dialog|plain
  local requested
  requested="${HOMELAB_UI_MODE:-auto}"

  case "${requested}" in
    dialog)
      if ui__has_dialog && ui__is_tty; then
        UI_MODE="dialog"
      else
        UI_MODE="console"
      fi
      ;;
    plain|console)
      UI_MODE="console"
      ;;
    auto|*)
      if ui__has_dialog && ui__is_tty; then
        UI_MODE="dialog"
      else
        UI_MODE="console"
      fi
      ;;
  esac

  UI_HEIGHT="${HOMELAB_UI_HEIGHT:-20}"
  UI_WIDTH="${HOMELAB_UI_WIDTH:-70}"

  export UI_MODE UI_HEIGHT UI_WIDTH UI_BACKTITLE
  ui__log_if_available info "UI initialised (mode=${UI_MODE})"
  return 0
}

ui__msgbox() {
  # Best-effort message presentation.
  local title text
  title="$1"
  text="$2"

  set +o errexit
  if [[ "${UI_MODE}" == "dialog" ]] && ui__has_dialog && ui__is_tty; then
    dialog --backtitle "${UI_BACKTITLE}" --title "${title}" --msgbox "${text}" "${UI_HEIGHT}" "${UI_WIDTH}"
  else
    printf '%s: %s\n' "${title}" "${text}"
  fi
  set -o errexit

  return 0
}

ui_info() {
  local title text
  if [[ $# -ge 2 ]]; then
    title="$1"; shift || true
    text="$1"; shift || true
    if [[ $# -gt 0 ]]; then
      text="${text} $*"
    fi
  else
    title="${UI_BACKTITLE}"
    text="$*"
  fi
  ui__log_if_available info "UI info: ${title}"
  ui__msgbox "${title}" "${text}"
}

ui_warn() {
  local title text
  if [[ $# -ge 2 ]]; then
    title="$1"; shift || true
    text="$1"; shift || true
    if [[ $# -gt 0 ]]; then
      text="${text} $*"
    fi
  else
    title="${UI_BACKTITLE}"
    text="$*"
  fi
  ui__log_if_available warn "UI warn: ${title}"
  ui__msgbox "${title}" "${text}"
}

ui_error() {
  local title text
  if [[ $# -ge 2 ]]; then
    title="$1"; shift || true
    text="$1"; shift || true
    if [[ $# -gt 0 ]]; then
      text="${text} $*"
    fi
  else
    title="${UI_BACKTITLE}"
    text="$*"
  fi
  ui__log_if_available error "UI error: ${title}"
  ui__msgbox "${title}" "${text}"
}

ui_menu() {
  # Present a menu and echo the selected tag to stdout.
  # Returns 0 even when user cancels; caller should treat empty output as cancel.
  # Args:
  #   title, prompt, then repeating pairs: tag label
  local title prompt
  title="${1:-Menu}"; shift || true
  prompt="${1:-Select an option}"; shift || true

  local -a items
  items=("$@")

  local choice=""
  set +o errexit
  if [[ "${UI_MODE}" == "dialog" ]] && ui__has_dialog && ui__is_tty; then
    # dialog writes selection to stderr by default; redirect to stdout via FD juggling.
    choice=$(dialog --backtitle "${UI_BACKTITLE}" --title "${title}" \
      --menu "${prompt}" "${UI_HEIGHT}" "${UI_WIDTH}" 10 \
      "${items[@]}" \
      3>&1 1>&2 2>&3)
  else
    # Console / non-interactive fallback
    if ! ui__is_tty; then
      # Non-interactive: choose default if provided, otherwise return empty.
      choice="${HOMELAB_DEFAULT_CHOICE:-}"
    else
      printf '%s\n%s\n' "${title}" "${prompt}" >&2
      local i=0
      local -a tags labels
      while (( i < ${#items[@]} )); do
        tags+=("${items[$i]}")
        labels+=("${items[$((i+1))]}")
        i=$((i+2))
      done

      local idx
      for idx in "${!tags[@]}"; do
        printf '  %s) %s\n' "$((idx+1))" "${labels[$idx]}" >&2
      done
      printf 'Choose [1-%s] (Enter to cancel): ' "${#tags[@]}" >&2
      read -r ans || ans=""
      if [[ -n "${ans}" ]] && [[ "${ans}" =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= ${#tags[@]} )); then
        choice="${tags[$((ans-1))]}"
      else
        choice=""
      fi
    fi
  fi
  set -o errexit

  printf '%s' "${choice}"
  return 0
}
