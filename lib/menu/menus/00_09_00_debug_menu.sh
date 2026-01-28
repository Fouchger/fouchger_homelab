#!/usr/bin/env bash
# =============================================================================
# Filename: lib/menu/menus/00_07_00_ansible_menu.sh
# Created: 28/01/2026
# Updated: 28/01/2026
# Description: 
#
# Notes
#   - 
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

if [[ -z "${REPO_ROOT:-}" ]]; then
  REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi

#=============================================================================
# Sub Menu Setup
#=============================================================================
# source "${REPO_ROOT}/lib/menu/menus/<sub menu file name>.sh

#------------------------
# Main Menu Option:   9 "Debug"
#------------------------
debug_menu() {
  while true; do
    local choice=""
    ui_menu "🐞 Debug" "Diagnostics and troubleshooting tools:" choice \
      1 "🎥 Session capture: Enable" \
      2 "🛑 Session capture: Disable" \
      3 "📋 Session capture: Status" \
      4 "📜 Session capture: Show last 200 lines" \
      5 "📡 Session capture: Live tail (Ctrl+C to exit)" \
      6 "🔙 Back"

    [[ -n "${choice}" ]] || return 0

    case "${choice}" in
      1)
        "${REPO_ROOT}/scripts/core/session_capture.sh" on >/dev/null 2>&1 || true
        ui_msgbox "Session capture" "Enabled. It will auto-start next time you run 'make menu'."
        make menu
        debug_menu
        ;;
      2)
        "${REPO_ROOT}/scripts/core/session_capture.sh" off >/dev/null 2>&1 || true
        ui_msgbox "Session capture" "Disabled."
        make menu
        debug_menu
        ;;
      3)
        local tmp
        tmp="$(ui_tmpfile session_capture_status)"
        "${REPO_ROOT}/scripts/core/session_capture.sh" status >"${tmp}" 2>&1 || true
        ui_textbox "Session capture status" "${tmp}" || true
        ;;
      4)
        local tmp
        tmp="$(ui_tmpfile session_capture_tail)"
        if [[ -f "${HOME}/.ptlog/current.log" ]]; then
          tail -n 200 "${HOME}/.ptlog/current.log" >"${tmp}" 2>&1 || true
          ui_textbox "Session capture last 200 lines" "${tmp}" || true
        else
          ui_msgbox "Session capture" "No current log found at ${HOME}/.ptlog/current.log"
        fi
        ;;
      5)
        ui_exit
        if command -v ptlog >/dev/null 2>&1; then
          ptlog tail || true
        elif [[ -f "${HOME}/.ptlog/current.log" ]]; then
          tail -f "${HOME}/.ptlog/current.log" || true
        else
          printf '%s\n' "No current log found. Enable capture and run a workflow first." >&2
        fi
        ui_init
        ;;
      6) return 0 ;;
      *) return 0 ;;
    esac
  done
}
