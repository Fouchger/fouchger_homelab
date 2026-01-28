#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/ui_flows.sh
# Purpose : UI flows and menu wiring
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

apm_ui_choose_profile() {
  local title="$1"
  local prompt="$2"
  local choice=""
  ui_menu "${title}" "${prompt}" choice \
    basic "Core ops baseline" \
    dev "Developer tooling (build/runtime)" \
    automation "Ansible/Terraform/Packer focus" \
    platform "Automation + containers/K8s CLI" \
    database "Databases and data services" \
    observability "Observability tooling" \
    security "Security tooling" \
    all "All profile apps (unique union)"
  printf '%s' "${choice}"
}

apm_ui_run_checklist() {
  write_default_env_if_missing
  load_env || true

  local -a items=()
  local row type key label def pkgs_csv desc _strategy _version_var
  local heading_count=0 blank_count=0 status

  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc _strategy _version_var <<<"${row}"
    case "${type}" in
      HEADING)
        heading_count=$((heading_count + 1))
        items+=( "__hdr_${heading_count}" "=== ${key} ===" "off" )
        ;;
      BLANK)
        blank_count=$((blank_count + 1))
        items+=( "__blk_${blank_count}" " " "off" )
        ;;
      APP)
        validate_key "${key}" || continue
        if [[ "$(get_selection_value "${key}")" == "1" ]]; then status="on"; else status="off"; fi
        items+=( "${key}" "${label} | ${desc}" "${status}" )
        ;;
    esac
  done

  local raw=""
  ui_checklist "Select Applications" "Toggle selections. Unticked apps will be removed (only if installed by this manager)." raw "${items[@]}"
  [[ -n "${raw}" ]] || return 0

  # Turn returned list into chosen map
  declare -A chosen=()
  local k
  for k in ${raw}; do
    [[ "${k}" == __hdr_* || "${k}" == __blk_* ]] && continue
    chosen["$k"]=1
  done

  for k in $(catalogue_all_app_keys); do
    if [[ -n "${chosen[$k]:-}" ]]; then
      printf -v "$(key_to_var "${k}")" '%s' "1"
    else
      printf -v "$(key_to_var "${k}")" '%s' "0"
    fi
  done

  persist_current_selection_vars
}

apm_ui_apply_defaults_replace() {
  if ui_confirm "Apply Defaults" "Apply the catalogue defaults now?\n\nThis will REPLACE all existing app selections.\n\nProceed?"; then
    apply_defaults_replace
    ui_msgbox "Done" "Defaults applied. Selections have been replaced."
  fi
}

apm_ui_apply_profile_replace() {
  local choice
  choice="$(apm_ui_choose_profile "Apply Profile (Replace)" "Choose a profile (replaces selections):")"
  [[ -n "${choice}" ]] || return 0

  if ui_confirm "Confirm" "Apply profile '${choice}' in REPLACE mode?\n\nThis replaces all current selections."; then
    apply_profile_replace "${choice}"
    ui_msgbox "Done" "Profile '${choice}' applied (replace)."
  fi
}

apm_ui_apply_profile_append() {
  local choice
  choice="$(apm_ui_choose_profile "Apply Profile (Append)" "Choose a profile (adds to current selections):")"
  [[ -n "${choice}" ]] || return 0

  if ui_confirm "Confirm" "Append profile '${choice}' to the current selections?\n\nExisting selections will be kept."; then
    apply_profile_append "${choice}"
    ui_msgbox "Done" "Profile '${choice}' applied (append)."
  fi
}

apm_ui_main_menu() {
  apm_init_paths || return 1
  write_default_env_if_missing || true

  while :; do
    local choice=""
    ui_menu "App Manager" "Choose an action:" choice \
      defaults "Apply defaults (replace selections)" \
      prof_replace "Apply profile (replace selections)" \
      prof_append "Apply profile (append selections)" \
      select "Select apps (interactive)" \
      pins "Edit version pins" \
      apply "Apply changes (install/uninstall)" \
      audit "Audit selected apps" \
      back "Back"

    case "${choice}" in
      defaults)     apm_ui_apply_defaults_replace ;;
      prof_replace) apm_ui_apply_profile_replace ;;
      prof_append)  apm_ui_apply_profile_append ;;
      select)       apm_ui_run_checklist ;;
      pins)         apm_ui_edit_version_pins ;;     # implemented in strategies.sh section below? (kept as separate function in strategies file is not right)
      apply)        apply_changes ;;
      audit)        audit_selected_apps || true ;;
      back|"")      return 0 ;;
    esac
  done
}
