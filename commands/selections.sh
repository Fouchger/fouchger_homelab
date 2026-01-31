#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/selections.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Command entrypoint (selections).
# Purpose: Manually set apps to install and/or uninstall (without executing).
# Usage:
#   ./commands/selections.sh
#   ./commands/selections.sh --install curl,jq --uninstall docker
# Notes:
#   - Selections are persisted to state/selections.env (non-secret).
# -----------------------------------------------------------------------------

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/command_runner.sh"

selections_impl() {
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/yaml.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/state.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/runtime.sh"

  local install_arg=""
  local uninstall_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install)
        install_arg="${2:-}"
        shift 2
        ;;
      --uninstall)
        uninstall_arg="${2:-}"
        shift 2
        ;;
      -h|--help)
        ui_info "Selections" "Options:\n  --install <comma-separated app IDs>\n  --uninstall <comma-separated app IDs>\n\nIf not provided, interactive selection is used (dialog preferred)."
        return 0
        ;;
      *)
        log_warn "selections: ignoring unknown argument: $1" || true
        shift
        ;;
    esac
  done

  state_selections_load

  if [[ -n "${install_arg}" ]] || [[ -n "${uninstall_arg}" ]]; then
    if [[ -n "${install_arg}" ]]; then
      SELECTED_APPS_INSTALL="${install_arg}"
    fi
    if [[ -n "${uninstall_arg}" ]]; then
      SELECTED_APPS_UNINSTALL="${uninstall_arg}"
    fi
  else
    if [[ "${UI_MODE}" == "dialog" ]]; then
      local -a items
      items=()
      local id
      while IFS= read -r id; do
        [[ -z "${id}" ]] && continue
        local name desc
        name="$(yaml_get "${ROOT_DIR}/config/apps.yml" "apps.${id}.name" 2>/dev/null || echo "${id}")"
        desc="$(yaml_get "${ROOT_DIR}/config/apps.yml" "apps.${id}.description" 2>/dev/null || echo "")"
        items+=("${id}" "${name} - ${desc}" "OFF")
      done < <(yaml_list "${ROOT_DIR}/config/apps.yml" "apps")

      local sel_install sel_uninstall
      set +e
      sel_install="$(ui_checklist "Select installs" "Select applications to install" "${items[@]}")"
      local rc1=$?
      sel_uninstall="$(ui_checklist "Select uninstalls" "Select applications to uninstall" "${items[@]}")"
      local rc2=$?
      set -e

      if [[ ${rc1} -ne 0 ]] && [[ ${rc2} -ne 0 ]]; then
        ui_info "Selections" "No changes made."
        return 0
      fi

      if [[ ${rc1} -eq 0 ]]; then
        SELECTED_APPS_INSTALL="$(echo "${sel_install}" | tr -d '"' | tr ' ' ',')"
      fi
      if [[ ${rc2} -eq 0 ]]; then
        SELECTED_APPS_UNINSTALL="$(echo "${sel_uninstall}" | tr -d '"' | tr ' ' ',')"
      fi
    else
      # Text/console fallback: use input boxes with a comma-separated list.
      local catalogue
      catalogue="$(yaml_list "${ROOT_DIR}/config/apps.yml" "apps" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/ $//')"
      local v
      v="$(ui_inputbox "Install apps" "Enter comma-separated app IDs. Available: ${catalogue}" "${SELECTED_APPS_INSTALL}")"
      if [[ -n "${v}" ]]; then
        SELECTED_APPS_INSTALL="${v}"
      fi
      v="$(ui_inputbox "Uninstall apps" "Enter comma-separated app IDs. Available: ${catalogue}" "${SELECTED_APPS_UNINSTALL}")"
      if [[ -n "${v}" ]]; then
        SELECTED_APPS_UNINSTALL="${v}"
      fi
    fi
  fi

  state_selections_save

  runtime_latest_upsert "SELECTED_PROFILE" "${SELECTED_PROFILE:-}"
  runtime_latest_upsert "SELECTED_APPS_INSTALL" "${SELECTED_APPS_INSTALL:-}"
  runtime_latest_upsert "SELECTED_APPS_UNINSTALL" "${SELECTED_APPS_UNINSTALL:-}"
  runtime_latest_upsert "LAST_STEP_COMPLETED" "selections"

  runtime_summary_line "selections updated" || true

  ui_info "Selections" "Saved.\n\nInstall apps: ${SELECTED_APPS_INSTALL:-<none>}\nUninstall apps: ${SELECTED_APPS_UNINSTALL:-<none>}"
  return 0
}

main() {
  command_run "selections" selections_impl "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
