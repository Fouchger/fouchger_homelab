#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/ui_dialog.sh
# Created: 2026-01-30
# Updated: 2026-01-31
#
# Description:
#   UI helper layer for fouchger_homelab, using `dialog` when available with
#   deterministic fallbacks for Proxmox LXC/VM environments.
#
# Purpose:
#   - Provide a stable public UI helper API used across commands.
#   - Keep a consistent look and feel across interactive and non-interactive runs.
#   - Never terminate the runtime (UI calls are best-effort).
#
# Decision tree (Sprint 2):
#   1) If /dev/tty is usable AND TERM isn't dumb AND dialog exists:
#        Use dialog bound to /dev/tty (curses UI)
#   2) Else if interactive shell (-t 0):
#        Use simple text prompts (stdin/stdout)
#   3) Else:
#        Non-interactive defaults and logging (no blocking reads)
#
# Public API (Sprint 2, backwards compatible):
#   ui_init
#   ui_info
#   ui_warn
#   ui_error
#   ui_menu
#
# Extended API (available for future commands; safe no-ops/headless defaults):
#   ui_msgbox, ui_infobox, ui_yesno
#   ui_inputbox, ui_passwordbox
#   ui_form, ui_mixedform, ui_passwordform
#   ui_checklist, ui_radiolist, ui_buildlist, ui_treeview
#   ui_fselect, ui_dselect, ui_tailbox, ui_tailboxbg, ui_editbox
#   ui_calendar, ui_timebox, ui_rangebox
#   ui_prgbox, ui_programbox, ui_gauge
#   ui_and_widget
#
# Environment variables:
#   HOMELAB_UI_MODE         auto|dialog|plain|console (default: auto)
#   HOMELAB_UI_HEIGHT       default height (default: 20)
#   HOMELAB_UI_WIDTH        default width  (default: 70)
#   HOMELAB_UI_MENU_HEIGHT  default menu height (default: 10)
#   HOMELAB_DEFAULT_CHOICE  default menu tag for headless runs
#   HOMELAB_ASSUME_YES      1 to assume yes in headless yes/no (default: 0)
#   HOMELAB_DEFAULT_INPUT   default input value in headless inputbox
#
# Notes:
#   - UI functions are safe to call multiple times.
#   - If logger functions exist (log_info/log_warn/log_error), UI helpers will log.
#   - For menu selection, callers should treat empty output as cancel.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

UI_MODE="console"            # dialog|text|console (console=text in practice)
UI_WIDTH=200
UI_HEIGHT=50
UI_MENU_HEIGHT=10
UI_BACKTITLE="fouchger_homelab"
UI_TITLE="fouchger_homelab"
UI_INITIALISED=0

ui__has_dialog() {
  command -v dialog >/dev/null 2>&1
}

ui__tty_usable() {
  [[ -r /dev/tty && -w /dev/tty ]]
}

ui__term_usable() {
  [[ -n "${TERM:-}" && "${TERM}" != "dumb" ]]
}

ui__interactive_stdin() {
  [[ -t 0 ]]
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

ui__mode_detect() {
  # Computes UI_MODE per decision tree, optionally overridden by HOMELAB_UI_MODE.
  local requested
  requested="${HOMELAB_UI_MODE:-auto}"

  case "${requested}" in
    dialog)
      if ui__has_dialog && ui__tty_usable && ui__term_usable; then
        echo "dialog"
      elif ui__interactive_stdin; then
        echo "text"
      else
        echo "console"
      fi
      ;;
    plain|console)
      if ui__interactive_stdin; then
        echo "text"
      else
        echo "console"
      fi
      ;;
    auto|*)
      if ui__has_dialog && ui__tty_usable && ui__term_usable; then
        echo "dialog"
      elif ui__interactive_stdin; then
        echo "text"
      else
        echo "console"
      fi
      ;;
  esac
}

ui_init() {
  # Idempotent initialiser.
  if [[ "${UI_INITIALISED}" -eq 1 ]]; then
    return 0
  fi
  UI_INITIALISED=1

  UI_MODE="$(ui__mode_detect)"

  UI_HEIGHT="${HOMELAB_UI_HEIGHT:-20}"
  UI_WIDTH="${HOMELAB_UI_WIDTH:-70}"
  UI_MENU_HEIGHT="${HOMELAB_UI_MENU_HEIGHT:-10}"
  UI_BACKTITLE="${HOMELAB_UI_BACKTITLE:-fouchger_homelab}"
  UI_TITLE="${HOMELAB_UI_TITLE:-fouchger_homelab}"

  export UI_MODE UI_HEIGHT UI_WIDTH UI_MENU_HEIGHT UI_BACKTITLE UI_TITLE
  ui__log_if_available info "UI initialised (mode=${UI_MODE}, tty=$(ui__tty_usable && echo yes || echo no), term=${TERM:-unset})"
  return 0
}

ui__dialog_run() {
  # Runs dialog bound to /dev/tty and prints captured output to stdout.
  # Returns dialog exit code (0 OK, 1 Cancel/No, 255 Esc).
  local out rc
  out="$(mktemp -t homelab.dialog.XXXXXX)"

  set +o errexit
  dialog --backtitle "${UI_BACKTITLE}" --title "${UI_TITLE}" "$@" </dev/tty >/dev/tty 2>"${out}"
  rc=$?
  set -o errexit

  if [[ -s "${out}" ]]; then
    cat "${out}"
  fi
  rm -f -- "${out}" || true
  return "${rc}"
}

ui__text_pause() {
  # Best-effort pause without blocking in non-interactive contexts.
  if ui__interactive_stdin; then
    read -r _ </dev/stdin || true
  fi
  return 0
}

ui_msgbox() {
  local title text height width
  title="${1:-${UI_TITLE}}"; shift || true
  text="${1:-}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true

  set +o errexit
  case "${UI_MODE}" in
    dialog)
      UI_TITLE="${title}"
      ui__dialog_run --msgbox "${text}" "${height}" "${width}" >/dev/null || true
      ;;
    text)
      printf '\n%s: %s\n' "${title}" "${text}" >&2
      printf 'Press Enter to continue...' >&2
      ui__text_pause
      printf '\n' >&2
      ;;
    console|*)
      printf '%s: %s\n' "${title}" "${text}" >&2
      ui__log_if_available info "msgbox(headless): ${title}: ${text}"
      ;;
  esac
  set -o errexit
  return 0
}

ui_infobox() {
  local title text height width
  title="${1:-${UI_TITLE}}"; shift || true
  text="${1:-}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true

  set +o errexit
  case "${UI_MODE}" in
    dialog)
      UI_TITLE="${title}"
      dialog --backtitle "${UI_BACKTITLE}" --title "${UI_TITLE}" --infobox "${text}" "${height}" "${width}" </dev/tty >/dev/tty || true
      ;;
    text)
      printf '\n%s: %s\n' "${title}" "${text}" >&2
      ;;
    console|*)
      ui__log_if_available info "infobox(headless): ${title}: ${text}"
      ;;
  esac
  set -o errexit
  return 0
}

ui_yesno() {
  # Returns 0 for yes, 1 for no/cancel.
  local title text height width
  title="${1:-${UI_TITLE}}"; shift || true
  text="${1:-}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true

  local rc=1
  set +o errexit
  case "${UI_MODE}" in
    dialog)
      UI_TITLE="${title}"
      ui__dialog_run --yesno "${text}" "${height}" "${width}" >/dev/null
      rc=$?
      ;;
    text)
      printf '%s: %s [y/N]: ' "${title}" "${text}" >&2
      local ans=""
      read -r ans </dev/stdin || ans=""
      if [[ "${ans}" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
        rc=0
      else
        rc=1
      fi
      ;;
    console|*)
      if [[ "${HOMELAB_ASSUME_YES:-0}" == "1" ]]; then
        ui__log_if_available info "yesno(headless): assumed YES (${title})"
        rc=0
      else
        ui__log_if_available info "yesno(headless): assumed NO (${title})"
        rc=1
      fi
      ;;
  esac
  set -o errexit
  return "${rc}"
}

ui_inputbox() {
  # Prints entered value to stdout. Returns 0 for OK, 1 for cancel in dialog/text.
  local title prompt init height width
  title="${1:-${UI_TITLE}}"; shift || true
  prompt="${1:-Enter value}"; shift || true
  init="${1:-${HOMELAB_DEFAULT_INPUT:-}}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true

  local rc=0 val=""
  set +o errexit
  case "${UI_MODE}" in
    dialog)
      UI_TITLE="${title}"
      val="$(ui__dialog_run --inputbox "${prompt}" "${height}" "${width}" "${init}")"
      rc=$?
      ;;
    text)
      printf '%s: %s ' "${title}" "${prompt}" >&2
      read -r val </dev/stdin || val=""
      [[ -z "${val}" ]] && val="${init}"
      rc=0
      ;;
    console|*)
      val="${init}"
      ui__log_if_available info "inputbox(headless): default used (${title})"
      rc=0
      ;;
  esac
  set -o errexit

  printf '%s' "${val}"
  return "${rc}"
}

ui_passwordbox() {
  # Prints entered value to stdout. In headless mode returns empty.
  local title prompt height width
  title="${1:-${UI_TITLE}}"; shift || true
  prompt="${1:-Enter password}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true

  local rc=0 val=""
  set +o errexit
  case "${UI_MODE}" in
    dialog)
      UI_TITLE="${title}"
      val="$(ui__dialog_run --insecure --passwordbox "${prompt}" "${height}" "${width}")"
      rc=$?
      ;;
    text)
      printf '%s: %s ' "${title}" "${prompt}" >&2
      if command -v stty >/dev/null 2>&1; then
        stty -echo </dev/stdin || true
        read -r val </dev/stdin || val=""
        stty echo </dev/stdin || true
        printf '\n' >&2
      else
        read -r val </dev/stdin || val=""
      fi
      rc=0
      ;;
    console|*)
      ui__log_if_available warn "passwordbox(headless): returning empty password (${title})"
      val=""
      rc=0
      ;;
  esac
  set -o errexit

  printf '%s' "${val}"
  return "${rc}"
}

ui_form() {
  local title height width formheight
  title="${1:-Form}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true
  formheight="${1:-10}"; shift || true

  if [[ "${UI_MODE}" == "dialog" ]]; then
    UI_TITLE="${title}"
    ui__dialog_run --form "${title}" "${height}" "${width}" "${formheight}" "$@"
    return $?
  fi
  ui__log_if_available warn "form: not supported without dialog (${title})"
  return 1
}

ui_mixedform() {
  local title height width formheight
  title="${1:-Mixed Form}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true
  formheight="${1:-10}"; shift || true

  if [[ "${UI_MODE}" == "dialog" ]]; then
    UI_TITLE="${title}"
    ui__dialog_run --mixedform "${title}" "${height}" "${width}" "${formheight}" "$@"
    return $?
  fi
  ui__log_if_available warn "mixedform: not supported without dialog (${title})"
  return 1
}

ui_passwordform() {
  local title height width formheight
  title="${1:-Password Form}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true
  formheight="${1:-10}"; shift || true

  if [[ "${UI_MODE}" == "dialog" ]]; then
    UI_TITLE="${title}"
    ui__dialog_run --insecure --passwordform "${title}" "${height}" "${width}" "${formheight}" "$@"
    return $?
  fi
  ui__log_if_available warn "passwordform: not supported without dialog (${title})"
  return 1
}

ui_menu() {
  # Backwards compatible:
  # - Echo selected tag to stdout.
  # - Returns 0 even when cancelled; caller should treat empty output as cancel.
  local title prompt
  title="${1:-Menu}"; shift || true
  prompt="${1:-Select an option}"; shift || true

  local -a items
  items=("$@")

  local choice=""
  set +o errexit
  case "${UI_MODE}" in
    dialog)
      UI_TITLE="${title}"
      choice="$(dialog --backtitle "${UI_BACKTITLE}" --title "${UI_TITLE}"         --menu "${prompt}" "${UI_HEIGHT}" "${UI_WIDTH}" "${UI_MENU_HEIGHT}"         "${items[@]}"         3>&1 1>&2 2>&3 </dev/tty)"
      ;;
    text)
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
      local ans=""
      read -r ans </dev/stdin || ans=""
      if [[ -n "${ans}" ]] && [[ "${ans}" =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= ${#tags[@]} )); then
        choice="${tags[$((ans-1))]}"
      else
        choice=""
      fi
      ;;
    console|*)
      # Headless: choose explicit default if provided, else empty (cancel)
      choice="${HOMELAB_DEFAULT_CHOICE:-}"
      if [[ -n "${choice}" ]]; then
        ui__log_if_available info "menu(headless): default choice used (${choice})"
      else
        ui__log_if_available info "menu(headless): no default; returning empty selection"
      fi
      ;;
  esac
  set -o errexit

  printf '%s' "${choice}"
  return 0
}

ui_checklist() {
  local title prompt
  title="${1:-Checklist}"; shift || true
  prompt="${1:-Select items}"; shift || true
  if [[ "${UI_MODE}" == "dialog" ]]; then
    UI_TITLE="${title}"
    ui__dialog_run --checklist "${prompt}" "${UI_HEIGHT}" "${UI_WIDTH}" "${UI_MENU_HEIGHT}" "$@"
    return $?
  fi
  ui__log_if_available warn "checklist: not supported without dialog (${title})"
  return 1
}

ui_radiolist() {
  local title prompt
  title="${1:-Radiolist}"; shift || true
  prompt="${1:-Select one}"; shift || true
  if [[ "${UI_MODE}" == "dialog" ]]; then
    UI_TITLE="${title}"
    ui__dialog_run --radiolist "${prompt}" "${UI_HEIGHT}" "${UI_WIDTH}" "${UI_MENU_HEIGHT}" "$@"
    return $?
  fi
  ui__log_if_available warn "radiolist: not supported without dialog (${title})"
  return 1
}

ui_buildlist() {
  local title prompt
  title="${1:-Buildlist}"; shift || true
  prompt="${1:-Select items}"; shift || true
  if [[ "${UI_MODE}" == "dialog" ]]; then
    UI_TITLE="${title}"
    ui__dialog_run --buildlist "${prompt}" "${UI_HEIGHT}" "${UI_WIDTH}" "${UI_MENU_HEIGHT}" "$@"
    return $?
  fi
  ui__log_if_available warn "buildlist: not supported without dialog (${title})"
  return 1
}

ui_treeview() {
  local title prompt
  title="${1:-Treeview}"; shift || true
  prompt="${1:-Navigate}"; shift || true
  if [[ "${UI_MODE}" == "dialog" ]]; then
    UI_TITLE="${title}"
    ui__dialog_run --treeview "${prompt}" "${UI_HEIGHT}" "${UI_WIDTH}" "${UI_MENU_HEIGHT}" "$@"
    return $?
  fi
  ui__log_if_available warn "treeview: not supported without dialog (${title})"
  return 1
}

ui_fselect() {
  local path height width
  path="${1:-.}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true
  if [[ "${UI_MODE}" == "dialog" ]]; then
    ui__dialog_run --fselect "${path}" "${height}" "${width}"
    return $?
  fi
  ui__log_if_available warn "fselect: not supported without dialog"
  return 1
}

ui_dselect() {
  local path height width
  path="${1:-.}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true
  if [[ "${UI_MODE}" == "dialog" ]]; then
    ui__dialog_run --dselect "${path}" "${height}" "${width}"
    return $?
  fi
  ui__log_if_available warn "dselect: not supported without dialog"
  return 1
}

ui_tailbox() {
  local file height width
  file="${1:-}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true
  if [[ "${UI_MODE}" == "dialog" ]]; then
    dialog --backtitle "${UI_BACKTITLE}" --title "${UI_TITLE}" --tailbox "${file}" "${height}" "${width}" </dev/tty >/dev/tty
    return 0
  fi
  ui__log_if_available warn "tailbox: not supported without dialog"
  return 1
}

ui_tailboxbg() {
  local file height width
  file="${1:-}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true
  if [[ "${UI_MODE}" == "dialog" ]]; then
    dialog --backtitle "${UI_BACKTITLE}" --title "${UI_TITLE}" --tailboxbg "${file}" "${height}" "${width}" </dev/tty >/dev/tty
    return 0
  fi
  ui__log_if_available warn "tailboxbg: not supported without dialog"
  return 1
}

ui_editbox() {
  local file height width
  file="${1:-}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true
  if [[ "${UI_MODE}" == "dialog" ]]; then
    ui__dialog_run --editbox "${file}" "${height}" "${width}"
    return $?
  fi
  ui__log_if_available warn "editbox: not supported without dialog"
  return 1
}

ui_calendar() {
  if [[ "${UI_MODE}" == "dialog" ]]; then
    ui__dialog_run --calendar "Select date" "${UI_HEIGHT}" "${UI_WIDTH}" "${1:-}" "${2:-}" "${3:-}"
    return $?
  fi
  ui__log_if_available warn "calendar: not supported without dialog"
  return 1
}

ui_timebox() {
  if [[ "${UI_MODE}" == "dialog" ]]; then
    ui__dialog_run --timebox "Select time" "${UI_HEIGHT}" "${UI_WIDTH}" "${1:-}" "${2:-}" "${3:-}"
    return $?
  fi
  ui__log_if_available warn "timebox: not supported without dialog"
  return 1
}

ui_rangebox() {
  local prompt height width min max def
  prompt="${1:-Select value}"; shift || true
  height="${1:-${UI_HEIGHT}}"; shift || true
  width="${1:-${UI_WIDTH}}"; shift || true
  min="${1:-0}"; shift || true
  max="${1:-100}"; shift || true
  def="${1:-50}"; shift || true

  if [[ "${UI_MODE}" == "dialog" ]]; then
    ui__dialog_run --rangebox "${prompt}" "${height}" "${width}" "${min}" "${max}" "${def}"
    return $?
  fi
  ui__log_if_available warn "rangebox: not supported without dialog"
  return 1
}

ui_prgbox() {
  local title cmd
  title="${1:-Program Output}"; shift || true
  cmd="${1:-}"; shift || true
  if [[ "${UI_MODE}" == "dialog" ]]; then
    ui__dialog_run --prgbox "${title}" "${cmd}" "${UI_HEIGHT}" "${UI_WIDTH}"
    return $?
  fi
  ui__log_if_available info "prgbox(headless): running '${cmd}'"
  sh -c "${cmd}" || true
  return 0
}

ui_programbox() {
  local cmd
  cmd="${1:-}"
  if [[ "${UI_MODE}" == "dialog" ]]; then
    ui__dialog_run --programbox "${cmd}" "${UI_HEIGHT}" "${UI_WIDTH}"
    return $?
  fi
  ui__log_if_available info "programbox(headless): running '${cmd}'"
  sh -c "${cmd}" || true
  return 0
}

ui_gauge() {
  # Minimal helper: callers may pipe progress to dialog gauge.
  local message height width percent
  message="${1:-Working...}"; shift || true
  height="${1:-10}"; shift || true
  width="${1:-70}"; shift || true
  percent="${1:-0}"; shift || true

  if [[ "${UI_MODE}" == "dialog" ]]; then
    if [[ -t 0 ]]; then
      printf '%s\n' "${percent}" | dialog --backtitle "${UI_BACKTITLE}" --title "${UI_TITLE}" --gauge "${message}" "${height}" "${width}" "${percent}" </dev/tty >/dev/tty
    else
      dialog --backtitle "${UI_BACKTITLE}" --title "${UI_TITLE}" --gauge "${message}" "${height}" "${width}" "${percent}" </dev/tty >/dev/tty
    fi
    return 0
  fi

  ui__log_if_available info "gauge(headless): ${message} (${percent}%)"
  return 0
}

ui_and_widget() {
  # Exposes dialog's --and-widget for chained flows.
  if [[ "${UI_MODE}" == "dialog" ]]; then
    ui__dialog_run "$@"
    return $?
  fi
  ui__log_if_available warn "and-widget: not supported without dialog"
  return 1
}

# ------------------------------ Backwards wrappers ----------------------------

ui__msgbox() { ui_msgbox "$@"; }

ui_info() {
  local title text
  if [[ $# -ge 2 ]]; then
    title="$1"; shift || true
    text="$1"; shift || true
    if [[ $# -gt 0 ]]; then text="${text} $*"; fi
  else
    title="${UI_BACKTITLE}"
    text="$*"
  fi
  ui__log_if_available info "UI info: ${title}"
  ui_msgbox "${title}" "${text}"
}

ui_warn() {
  local title text
  if [[ $# -ge 2 ]]; then
    title="$1"; shift || true
    text="$1"; shift || true
    if [[ $# -gt 0 ]]; then text="${text} $*"; fi
  else
    title="${UI_BACKTITLE}"
    text="$*"
  fi
  ui__log_if_available warn "UI warn: ${title}"
  ui_msgbox "${title}" "${text}"
}

ui_error() {
  local title text
  if [[ $# -ge 2 ]]; then
    title="$1"; shift || true
    text="$1"; shift || true
    if [[ $# -gt 0 ]]; then text="${text} $*"; fi
  else
    title="${UI_BACKTITLE}"
    text="$*"
  fi
  ui__log_if_available error "UI error: ${title}"
  ui_msgbox "${title}" "${text}"
}
