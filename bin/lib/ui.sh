#!/usr/bin/env bash
# ==========================================================
# bin/lib/ui.sh
# Created: 29/01/2026
# Updated: 29/01/2026
# Purpose: Consistent dialog look/feel and reusable components.
# ==========================================================
set -euo pipefail

UI_BACKTITLE="Homelab Orchestrator"
UI_HEIGHT=20
UI_WIDTH=76

ui_init() {
  export DIALOGRC="${DIALOGRC:-/dev/null}"
}

ui_msg() {
  local title="$1"
  local msg="$2"
  dialog --backtitle "$UI_BACKTITLE" --title "$title" --msgbox "$msg" "$UI_HEIGHT" "$UI_WIDTH"
}

ui_yesno() {
  local title="$1"
  local msg="$2"
  dialog --backtitle "$UI_BACKTITLE" --title "$title" --yesno "$msg" "$UI_HEIGHT" "$UI_WIDTH"
}

ui_menu() {
  local title="$1"
  local prompt="$2"
  shift 2
  dialog --backtitle "$UI_BACKTITLE" --title "$title" --menu "$prompt" "$UI_HEIGHT" "$UI_WIDTH" 12 "$@" 3>&1 1>&2 2>&3
}

ui_checklist() {
  local title="$1"
  local prompt="$2"
  shift 2
  dialog --backtitle "$UI_BACKTITLE" --title "$title" --checklist "$prompt" "$UI_HEIGHT" "$UI_WIDTH" 12 "$@" 3>&1 1>&2 2>&3
}
