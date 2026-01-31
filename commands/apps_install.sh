#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/apps_install.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Command entrypoint (apps_install).
# Purpose: Select and install local applications based on profile or manual selection.
# Usage:
#   ./commands/apps_install.sh
#   ./commands/apps_install.sh --apps curl,jq
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

apps_install_impl() {
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
        ui_info "Apps install" "Options:\n  --apps <comma-separated app IDs>\n\nIf not provided, selection is taken from state/selections.env or prompted (dialog only)."
        return 0
        ;;
      *)
        log_warn "apps_install: ignoring unknown argument: $1" || true
        shift
        ;;
    esac
  done

  state_selections_load

  if [[ -n "${apps_arg}" ]]; then
    SELECTED_APPS_INSTALL="${apps_arg}"
  fi

  # If empty, prompt in dialog mode.
  if [[ -z "${SELECTED_APPS_INSTALL}" ]]; then
    if [[ "${UI_MODE}" == "dialog" ]]; then
      local -a items
      items=()
      local id
      while IFS= read -r id; do
        [[ -z "${id}" ]] && continue
        local name desc status
        name="$(yaml_get "${ROOT_DIR}/config/apps.yml" "apps.${id}.name" 2>/dev/null || echo "${id}")"
        desc="$(yaml_get "${ROOT_DIR}/config/apps.yml" "apps.${id}.description" 2>/dev/null || echo "")"
        status="OFF"
        # default selection from catalogue
        if [[ "$(yaml_get "${ROOT_DIR}/config/apps.yml" "apps.${id}.default_selected" 2>/dev/null || echo "false")" == "True" ]] || \
           [[ "$(yaml_get "${ROOT_DIR}/config/apps.yml" "apps.${id}.default_selected" 2>/dev/null || echo "false")" == "true" ]]; then
          status="ON"
        fi
        items+=("${id}" "${name} - ${desc}" "${status}")
      done < <(yaml_list "${ROOT_DIR}/config/apps.yml" "apps")

      local selected
      set +e
      selected="$(ui_checklist "Install apps" "Select applications to install" "${items[@]}")"
      local rc=$?
      set -e
      if [[ ${rc} -ne 0 ]]; then
        ui_info "Apps" "No changes made."
        return 0
      fi
      SELECTED_APPS_INSTALL="$(echo "${selected}" | tr -d '"' | tr ' ' ',')"
    else
      ui_warn "Apps selection" "Install selection requires dialog. Use --apps or run selections first."
      return 0
    fi
  fi

  SELECTED_APPS_INSTALL="$(python3 - <<'PY' "${SELECTED_APPS_INSTALL}"
import sys
raw=sys.argv[1]
items=[x.strip() for x in raw.split(',') if x.strip()]
print(','.join(items))
PY
)"

  state_selections_save

  runtime_latest_upsert "SELECTED_PROFILE" "${SELECTED_PROFILE:-}"
  runtime_latest_upsert "SELECTED_APPS_INSTALL" "${SELECTED_APPS_INSTALL}"
  runtime_latest_upsert "SELECTED_APPS_UNINSTALL" "${SELECTED_APPS_UNINSTALL:-}"
  runtime_latest_upsert "LAST_STEP_COMPLETED" "apps_install_selection"

  if [[ -z "${SELECTED_APPS_INSTALL}" ]]; then
    ui_info "Apps install" "No apps selected for install."
    return 0
  fi

  if is_true "${DRY_RUN:-false}"; then
    local missing=""
    local id module
    IFS=',' read -r -a ids <<<"${SELECTED_APPS_INSTALL}"
    for id in "${ids[@]}"; do
      module="$(yaml_get "${ROOT_DIR}/config/apps.yml" "apps.${id}.install.module" 2>/dev/null || true)"
      if [[ -z "${module}" ]] || [[ ! -f "${ROOT_DIR}/${module}" ]]; then
        missing+="\n - ${id}: missing module (${module})"
      fi
    done

    runtime_latest_upsert "LAST_STEP_COMPLETED" "apps_install_dry_run"
    ui_info "Apps install (dry run)" "Would install:\n${SELECTED_APPS_INSTALL}\n\nModule checks:${missing:-\n - OK}"
    return 0
  fi

  log_section "Apps install"
  runtime_summary_line "apps_install: ${SELECTED_APPS_INSTALL}" || true

  local overall_rc=0
  local id module
  IFS=',' read -r -a ids <<<"${SELECTED_APPS_INSTALL}"
  for id in "${ids[@]}"; do
    module="$(yaml_get "${ROOT_DIR}/config/apps.yml" "apps.${id}.install.module" 2>/dev/null || true)"
    if [[ -z "${module}" ]] || [[ ! -f "${ROOT_DIR}/${module}" ]]; then
      log_error "Missing install module" "app=${id}" "module=${module}" || true
      overall_rc=1
      continue
    fi

    log_section "Install: ${id}" || true
    set +e
    bash "${ROOT_DIR}/${module}"
    local rc=$?
    set -e
    if [[ ${rc} -ne 0 ]]; then
      log_error "App install failed" "app=${id}" "rc=${rc}" || true
      overall_rc=1
      if [[ "${HOMELAB_APPS_FAILURE_POLICY:-stop}" == "stop" ]]; then
        log_warn "Stopping on first failure" "app=${id}" || true
        break
      fi
    else
      log_info "App installed" "app=${id}" || true
    fi
  done

  runtime_latest_upsert "LAST_STEP_COMPLETED" "apps_install"

  if [[ ${overall_rc} -eq 0 ]]; then
    ui_info "Apps install" "Install completed.\n\nApps: ${SELECTED_APPS_INSTALL}"
  else
    ui_warn "Apps install" "Install completed with errors. Check logs.\n\nApps: ${SELECTED_APPS_INSTALL}"
  fi

  return ${overall_rc}
}

main() {
  command_run "apps_install" apps_install_impl "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
