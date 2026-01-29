#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/questionnaire.sh
# Created: 29/01/2026
# Updated: 29/01/2026
# Description: Dialog questionnaire to select a profile and/or apps, then save selection state.
#
# Notes
#   - Requires dialog to be installed.
#   - This is intentionally UI-light; you can wrap it with your ui.sh helpers later.
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

APP_MGR_MENU_HEIGHT="${APP_MGR_MENU_HEIGHT:-22}"
APP_MGR_MENU_WIDTH="${APP_MGR_MENU_WIDTH:-86}"

questionnaire_require_dialog() { command -v dialog >/dev/null 2>&1 || { printf '%s\n' "dialog is required." >&2; return 1; }; }

questionnaire_select_profile() {
  questionnaire_require_dialog
  local items=()
  while read -r key; do
    items+=("$key" "$(profile_get_description "$key")")
  done < <(profile_list_keys)
  items+=("manual" "Manual selection only (no profile)")
  dialog --clear --stdout --title "Select Profile" --menu "Choose a profile to pre-select apps, or choose manual."     "$APP_MGR_MENU_HEIGHT" "$APP_MGR_MENU_WIDTH" 12 "${items[@]}"
}

questionnaire_profile_merge_mode() {
  questionnaire_require_dialog
  dialog --clear --stdout --title "Apply Profile"     --menu "How do you want to apply the profile to current selections?"     12 "$APP_MGR_MENU_WIDTH" 2     "replace" "Replace current selections with profile defaults"     "append" "Append profile apps to current selections (keep existing)"
}

questionnaire_apply_profile_to_selection() {
  local profile_key="$1"; local mode="$2"
  if [[ "$mode" == "replace" ]]; then
    for k in "${!APP_SELECTION[@]}"; do APP_SELECTION["$k"]="OFF"; done
  fi
  local apps; apps="$(profile_get_apps "$profile_key")"
  for a in $apps; do APP_SELECTION["$a"]="ON"; done
}

questionnaire_select_apps() {
  questionnaire_require_dialog
  local items=()
  local row type key label _def _packages _desc _strategy _ver
  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label _def _packages _desc _strategy _ver <<< "$row" || true
    if [[ "$type" == "APP" ]]; then
      local state="${APP_SELECTION[$key]:-OFF}"
      local onoff="off"; [[ "$state" == "ON" ]] && onoff="on"
      items+=("$key" "$label" "$onoff")
    fi
  done

  local selected
  selected="$(dialog --clear --stdout --title "Select Applications" --separate-output     --checklist "Use Space to toggle. Enter to commit."     "$APP_MGR_MENU_HEIGHT" "$APP_MGR_MENU_WIDTH" 16 "${items[@]}")" || return 1

  for k in "${!APP_SELECTION[@]}"; do APP_SELECTION["$k"]="OFF"; done
  while read -r line; do APP_SELECTION["$line"]="ON"; done <<< "$selected"
}

questionnaire_run() {
  app_selection_load
  local profile; profile="$(questionnaire_select_profile)" || return 1
  if [[ "$profile" != "manual" ]]; then
    local mode; mode="$(questionnaire_profile_merge_mode)" || return 1
    questionnaire_apply_profile_to_selection "$profile" "$mode"
  fi
  questionnaire_select_apps
  app_selection_save
}
