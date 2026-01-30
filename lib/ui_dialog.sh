#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/ui_dialog.sh
# Created: 2026-01-30
# Updated: 2026-01-30
# Description: Dialog UI plumbing with graceful fallback to console output.
# Purpose: Standardise interaction patterns and keep a single look and feel.
# Usage:
#   source "${ROOT_DIR}/lib/ui_dialog.sh"
#   ui_init
#   ui_msg "Hello"
# Prerequisites:
#   - bash >= 4
#   - dialog (optional, falls back if missing)
# Notes:
#   - Sprint 1 provides plumbing only; richer menus land in later sprints.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

UI_MODE="console"   # console|dialog
UI_WIDTH=70
UI_HEIGHT=20

ui_has_dialog() {
  command -v dialog >/dev/null 2>&1
}

ui_init() {
  # Auto-enable dialog when available and running in a TTY.
  if ui_has_dialog && [[ -t 1 ]] && [[ -t 2 ]]; then
    UI_MODE="dialog"
  else
    UI_MODE="console"
  fi

  # Allow override from env.
  if [[ -n "${HOMELAB_UI_MODE:-}" ]]; then
    UI_MODE="${HOMELAB_UI_MODE}"
  fi

  # Basic sizing defaults. Users can override later in config/ui.yml.
  UI_HEIGHT="${HOMELAB_UI_HEIGHT:-20}"
  UI_WIDTH="${HOMELAB_UI_WIDTH:-70}"

  export UI_MODE UI_HEIGHT UI_WIDTH
}

ui_msg() {
  local title text
  title="${1:-fouchger_homelab}"
  text="${2:-}"

  if [[ "${UI_MODE}" == "dialog" ]] && ui_has_dialog; then
    dialog --backtitle "fouchger_homelab" --title "${title}" --msgbox "${text}" "${UI_HEIGHT}" "${UI_WIDTH}"
  else
    # Console fallback
    printf '%s\n' "${title}: ${text}"
  fi
}

ui_yesno() {
  local title text
  title="${1:-Confirm}"
  text="${2:-Are you sure?}"

  if [[ "${UI_MODE}" == "dialog" ]] && ui_has_dialog; then
    dialog --backtitle "fouchger_homelab" --title "${title}" --yesno "${text}" "${UI_HEIGHT}" "${UI_WIDTH}"
    return $?
  fi

  # Console fallback
  printf '%s: %s [y/N] ' "${title}" "${text}" >&2
  read -r ans
  [[ "${ans}" =~ ^[Yy]$ ]]
}
