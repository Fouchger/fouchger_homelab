#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/apps_uninstall.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Command entrypoint (apps_uninstall).
# Purpose: Select and uninstall local applications.
# Usage:
#   ./commands/apps_uninstall.sh
#   ./commands/apps_uninstall.sh --apps docker,terraform
# Notes:
#   - Prefers nala, with apt-get as fallback (see lib/pkg.sh).
#   - Selection is persisted to state/selections.env (non-secret).
#   - Writes non-secret handoff keys into state/runs/latest.env.
# -----------------------------------------------------------------------------

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/command_runner.sh"

apps_uninstall_impl() {
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/yaml.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/common.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/state.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/runtime.sh"

  local apps_arg=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apps)
        apps_arg="${2:-}"
        shift 2
        ;;
      -h|--help)
        ui_info "Apps uninstall" "Options:\n  --apps <comma-separated app IDs>\n\nIf not provided, selection is taken from state/selections.env or prompted (dialog only)."
        return 0
        ;;
      *)
        log_warn "apps_uninstall: ignoring unknown argument: $1" || true
        shift
        ;;
    esac
  done

  state_selections_load

  if [[ -n "${apps_arg}" ]]; then
    SELECTED_APPS_UNINSTALL="${apps_arg}"
  fi

  if [[ -z "${SELECTED_APPS_UNINSTALL}" ]]; then
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

      local selected
      set +e
      selected="$(ui_checklist "Uninstall apps" "Select applications to uninstall" "${items[@]}")"
      local rc=$?
      set -e
      if [[ ${rc} -ne 0 ]]; then
        ui_info "Apps" "No changes made."
        return 0
      fi
      SELECTED_APPS_UNINSTALL="$(echo "${selected}" | tr -d '"' | tr ' ' ',')"
    else
      ui_warn "Apps selection" "Uninstall selection requires dialog. Use --apps or run selections first."
      return 0
    fi
  fi

  SELECTED_APPS_UNINSTALL="$(python3 - <<'PY' "${SELECTED_APPS_UNINSTALL}"
import sys
raw=sys.argv[1]
items=[x.strip() for x in raw.split(',') if x.strip()]
print(','.join(items))
PY
)"

  state_selections_save

  runtime_latest_upsert "SELECTED_PROFILE" "${SELECTED_PROFILE:-}"
  runtime_latest_upsert "SELECTED_APPS_INSTALL" "${SELECTED_APPS_INSTALL:-}"
  runtime_latest_upsert "SELECTED_APPS_UNINSTALL" "${SELECTED_APPS_UNINSTALL}"
  runtime_latest_upsert "LAST_STEP_COMPLETED" "apps_uninstall_selection"

  if [[ -z "${SELECTED_APPS_UNINSTALL}" ]]; then
    ui_info "Apps uninstall" "No apps selected for uninstall."
    return 0
  fi

  if is_true "${DRY_RUN:-false}"; then
    local missing=""
    local id module
    IFS=',' read -r -a ids <<<"${SELECTED_APPS_UNINSTALL}"
    for id in "${ids[@]}"; do
      module="$(yaml_get "${ROOT_DIR}/config/apps.yml" "apps.${id}.uninstall.module" 2>/dev/null || true)"
      if [[ -z "${module}" ]] || [[ ! -f "${ROOT_DIR}/${module}" ]]; then
        missing+="\n - ${id}: missing module (${module})"
      fi
    done

    runtime_latest_upsert "LAST_STEP_COMPLETED" "apps_uninstall_dry_run"
    ui_info "Apps uninstall (dry run)" "Would uninstall:\n${SELECTED_APPS_UNINSTALL}\n\nModule checks:${missing:-\n - OK}"
    return 0
  fi

  log_section "Apps uninstall"
  runtime_summary_line "apps_uninstall: ${SELECTED_APPS_UNINSTALL}" || true

  local overall_rc=0
  local id module
  IFS=',' read -r -a ids <<<"${SELECTED_APPS_UNINSTALL}"
  for id in "${ids[@]}"; do
    module="$(yaml_get "${ROOT_DIR}/config/apps.yml" "apps.${id}.uninstall.module" 2>/dev/null || true)"
    if [[ -z "${module}" ]] || [[ ! -f "${ROOT_DIR}/${module}" ]]; then
      log_error "Missing uninstall module" "app=${id}" "module=${module}" || true
      overall_rc=1
      continue
    fi

    log_section "Uninstall: ${id}" || true
    set +e
    bash "${ROOT_DIR}/${module}"
    local rc=$?
    set -e
    if [[ ${rc} -ne 0 ]]; then
      log_error "App uninstall failed" "app=${id}" "rc=${rc}" || true
      overall_rc=1
      if [[ "${HOMELAB_APPS_FAILURE_POLICY:-stop}" == "stop" ]]; then
        log_warn "Stopping on first failure" "app=${id}" || true
        break
      fi
    else
      log_info "App uninstalled" "app=${id}" || true
    fi
  done

  runtime_latest_upsert "LAST_STEP_COMPLETED" "apps_uninstall"

  if [[ ${overall_rc} -eq 0 ]]; then
    ui_info "Apps uninstall" "Uninstall completed.\n\nApps: ${SELECTED_APPS_UNINSTALL}"
  else
    ui_warn "Apps uninstall" "Uninstall completed with errors. Check logs.\n\nApps: ${SELECTED_APPS_UNINSTALL}"
  fi

  return ${overall_rc}
}

main() {
  command_run "apps_uninstall" apps_uninstall_impl "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
