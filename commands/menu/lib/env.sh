#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/lib/env.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description:
#   Environment detection for UI execution modes.
#
# Notes:
#   - Works across Proxmox LXC/VM contexts where /dev/tty may be absent.
#   - You can force behaviour via:
#       FORCE_UI_MODE=dialog|text|noninteractive
#       DIALOG_TTY=/dev/pts/... (optional override)
# -----------------------------------------------------------------------------

detect_environment() {
  UI_MODE="noninteractive"
  TTY_DEV=""

  # Explicit override (useful for automation and troubleshooting).
  if [[ -n "${FORCE_UI_MODE:-}" ]]; then
    case "${FORCE_UI_MODE,,}" in
      dialog|text|noninteractive)
        UI_MODE="${FORCE_UI_MODE,,}"
        ;;
      *)
        UI_MODE="noninteractive"
        ;;
    esac
  else
    # Prefer dialog when we have a usable TTY and dialog is installed.
    if command -v dialog >/dev/null 2>&1 && [[ -t 0 && -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
      UI_MODE="dialog"
    elif [[ -t 0 || -t 1 ]]; then
      UI_MODE="text"
    fi
  fi

  # Work out the best TTY device for dialog.
  if [[ "$UI_MODE" == "dialog" ]]; then
    if [[ -n "${DIALOG_TTY:-}" && -e "${DIALOG_TTY}" ]]; then
      TTY_DEV="$DIALOG_TTY"
    else
      # tty(1) is more reliable than /dev/tty in containers.
      TTY_DEV="$(tty 2>/dev/null || true)"
      if [[ -z "$TTY_DEV" || "$TTY_DEV" == "not a tty" ]]; then
        [[ -c /dev/tty ]] && TTY_DEV="/dev/tty" || TTY_DEV=""
      fi
    fi

    # If we could not resolve a TTY, degrade gracefully.
    if [[ -z "$TTY_DEV" || ! -e "$TTY_DEV" ]]; then
      UI_MODE="text"
      TTY_DEV=""
    fi
  fi

  export UI_MODE
  export TTY_DEV
}
