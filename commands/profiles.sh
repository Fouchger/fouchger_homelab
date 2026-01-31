#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/profiles.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Command entrypoint (profiles).
# Purpose: Select an application profile (set of apps) and persist selections.
# Usage:
#   ./commands/profiles.sh
#   ./commands/profiles.sh --profile development --mode replace
# Notes:
#   - Profile defs live in config/profiles.yml.
#   - Selections persisted to state/selections.env (non-secret).
# -----------------------------------------------------------------------------

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/command_runner.sh"

profiles_impl() {
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/yaml.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/state.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/runtime.sh"

  local profile_arg=""
  local mode="replace" # replace|add

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        profile_arg="${2:-}"
        shift 2
        ;;
      --mode)
        mode="${2:-replace}"
        shift 2
        ;;
      -h|--help)
        ui_info "Profiles" "Options:\n  --profile <profile id>\n  --mode <replace|add>\n\nIf not provided, an interactive selection is used (dialog/text)."
        return 0
        ;;
      *)
        log_warn "profiles: ignoring unknown argument: $1" || true
        shift
        ;;
    esac
  done

  state_selections_load

  local profile="${profile_arg}"
  if [[ -z "${profile}" ]]; then
    # Render menu with profile ids.
    local -a items
    items=()
    local id
    while IFS= read -r id; do
      [[ -z "${id}" ]] && continue
      local name desc
      name="$(yaml_get "${ROOT_DIR}/config/profiles.yml" "profiles.${id}.name" 2>/dev/null || echo "${id}")"
      desc="$(yaml_get "${ROOT_DIR}/config/profiles.yml" "profiles.${id}.description" 2>/dev/null || echo "")"
      items+=("${id}" "${name} - ${desc}")
    done < <(yaml_list "${ROOT_DIR}/config/profiles.yml" "profiles")

    profile="$(ui_menu "Profiles" "Select a profile" "${items[@]}")"
    if [[ -z "${profile}" ]]; then
      ui_info "Profiles" "No changes made."
      return 0
    fi

    # Ask merge mode only when interactive.
    mode="$(ui_menu "Profiles" "How should this profile affect your existing selections" \
      "replace" "Replace current install selections" \
      "add" "Add profile apps to current install selections")"
    [[ -n "${mode}" ]] || mode="replace"
  fi

  # Resolve apps for profile.
  local apps_csv
  apps_csv="$(python3 - <<'PY' "${ROOT_DIR}/config/profiles.yml" "${profile}"
import sys, yaml
path=sys.argv[1]
profile=sys.argv[2]
with open(path,'r',encoding='utf-8') as f:
    data=yaml.safe_load(f) or {}
apps=(data.get('profiles',{}).get(profile,{}).get('apps') or [])
print(','.join(apps))
PY
)"

  if [[ -z "${apps_csv}" ]]; then
    ui_error "Profiles" "Profile not found or contains no apps: ${profile}"
    return 1
  fi

  state_selections_set_profile "${profile}" "${mode}" "${apps_csv}"
  state_selections_save

  runtime_latest_upsert "SELECTED_PROFILE" "${SELECTED_PROFILE}"
  runtime_latest_upsert "SELECTED_APPS_INSTALL" "${SELECTED_APPS_INSTALL}"
  runtime_latest_upsert "SELECTED_APPS_UNINSTALL" "${SELECTED_APPS_UNINSTALL:-}"
  runtime_latest_upsert "LAST_STEP_COMPLETED" "profiles"

  runtime_summary_line "profile selected: ${SELECTED_PROFILE} (${mode})" || true

  ui_info "Profiles" "Profile saved.\n\nProfile: ${SELECTED_PROFILE}\nInstall apps: ${SELECTED_APPS_INSTALL}"
  return 0
}

main() {
  command_run "profiles" profiles_impl "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
