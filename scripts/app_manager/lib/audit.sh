#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/audit.sh
# Purpose : Audit selected apps and produce a status report.
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# UI display helper (uses ui_textbox when available)
# -----------------------------------------------------------------------------
_app_test_show_dialog() {
  local report_file="$1"
  local title="${2:-App install status}"

  if declare -F ui_textbox >/dev/null 2>&1; then
    ui_textbox "${title}" "${report_file}"
    return 0
  fi

  ui_msgbox "${title}" "Report saved to:
${report_file}

(ui_textbox not available, so not displaying full content)"
}


audit_selected_apps() {

  apm_init_paths

  local env_file="${ENV_FILE}"
  local out_file="${1:-${APPM_DIR}/app-install-status.txt}"

  if [[ ! -f "${env_file}" ]]; then
    printf 'ERROR: Env file not found: %s\n' "${env_file}" >"${out_file}"
    _app_test_show_dialog "${out_file}" "App install status"
    return 0
  fi

  # Determine target user for per-user installs (NVM, etc.)
  local target_user target_home
  target_user="${SUDO_USER:-$USER}"
  target_home="$(getent passwd "${target_user}" | cut -d: -f6)"
  [[ -n "${target_home}" && -d "${target_home}" ]] || target_home=""

  local has_systemd=0
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    has_systemd=1
  fi

  local -a selected_keys=()
  local -i failures=0

  # Step 1: Read items marked APP_*=1 from ENV_FILE and convert to catalogue keys
  while IFS='=' read -r k v; do
    [[ -z "${k}" || "${k}" =~ ^[[:space:]]*# ]] && continue
    [[ "${k}" =~ ^APP_ ]] || continue
    [[ "${v}" == "1" ]] || continue

    local key
    key="${k#APP_}"
    key="$(printf '%s' "${key}" | tr '[:upper:]' '[:lower:]')"
    selected_keys+=("${key}")
  done < "${env_file}"

  # Header
  {
    printf 'fouchger_homelab app_test report\n'
    printf 'Generated : %s\n' "$(date -Is)"
    printf 'Host      : %s\n' "$(hostname -f 2>/dev/null || hostname)"
    printf 'Env file  : %s\n' "${env_file}"
    printf 'User      : %s (home: %s)\n' "${target_user}" "${target_home:-unknown}"
    printf '\n'
  } >"${out_file}"

  if [[ "${#selected_keys[@]}" -eq 0 ]]; then
    printf 'No applications are marked for installation (APP_*=1).\n' >>"${out_file}"
    _app_test_show_dialog "${out_file}" "App install status"
    return 0
  fi

  # Helper: find a catalogue row by key
  _catalogue_get_row_by_key() {
    local want_key="$1"
    local row type key label def pkgs_csv desc strategy version_var
    for row in "${APP_CATALOGUE[@]}"; do
      IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
      [[ "${type}" == "APP" ]] || continue
      [[ "${key}" == "${want_key}" ]] || continue
      printf '%s\n' "${row}"
      return 0
    done
    return 1
  }

  # Package install check (dpkg)
  _dpkg_is_installed() {
    local pkg="$1"
    dpkg-query -W --showformat='${Status}\n' "${pkg}" 2>/dev/null | grep -q "install ok installed"
  }

  # Table header
  {
    printf '%-18s  %-14s  %-10s  %s\n' "APP_KEY" "STRATEGY" "STATUS" "DETAILS"
    printf '%-18s  %-14s  %-10s  %s\n' "------" "--------" "------" "-------"
  } >>"${out_file}"

  # Step 2: Resolve + test
  local key row type label def pkgs_csv desc strategy version_var
  for key in "${selected_keys[@]}"; do
    row="$(_catalogue_get_row_by_key "${key}" || true)"

    if [[ -z "${row}" ]]; then
      printf '%-18s  %-14s  %-10s  %s\n' "${key}" "-" "UNKNOWN" "Selected but not found in APP_CATALOGUE" >>"${out_file}"
      failures=$((failures + 1))
      continue
    fi

    IFS='|' read -r type _k label def pkgs_csv desc strategy version_var <<<"${row}"
    strategy="${strategy:-apt}"

    local status="OK"
    local details=""

    case "${strategy}" in
      apt|hashicorp_repo|python|github_cli_repo|mongodb_repo|grafana_repo)
        if [[ -z "${pkgs_csv}" ]]; then
          status="OK"
          details="No dpkg packages declared"
        else
          local -a pkgs_arr=()
          pkgs_csv_to_array "${pkgs_csv}" pkgs_arr

          local -a missing=()
          local pkg
          for pkg in "${pkgs_arr[@]}"; do
            if ! _dpkg_is_installed "${pkg}"; then
              missing+=("${pkg}")
            fi
          done

          if ((${#missing[@]})); then
            status="MISSING"
            details="Missing dpkg: ${missing[*]}"
          else
            status="OK"
            details="All dpkg packages installed"
          fi
        fi

        if [[ "${has_systemd}" -eq 1 ]]; then
          if [[ "${key}" == "mongodb" ]]; then
            systemctl is-active --quiet mongod \
              && details="${details}; service: mongod active" \
              || details="${details}; service: mongod not active"
          elif [[ "${key}" == "grafana_alloy" ]]; then
            systemctl is-active --quiet alloy \
              && details="${details}; service: alloy active" \
              || details="${details}; service: alloy not active"
          fi
        fi
        ;;

      binary)
        case "${key}" in
          helm)    command -v helm >/dev/null 2>&1    && status="OK" details="helm present"    || status="MISSING" details="helm not found in PATH" ;;
          kubectl) command -v kubectl >/dev/null 2>&1 && status="OK" details="kubectl present" || status="MISSING" details="kubectl not found in PATH" ;;
          *)       command -v "${key}" >/dev/null 2>&1 && status="OK" details="binary present (${key})" || status="MISSING" details="binary not found in PATH (${key})" ;;
        esac
        ;;

      yq_binary)
        command -v yq >/dev/null 2>&1 && status="OK" details="yq present" || status="MISSING" details="yq not found in PATH"
        ;;

      sops_binary)
        command -v sops >/dev/null 2>&1 && status="OK" details="sops present" || status="MISSING" details="sops not found in PATH"
        ;;

      docker_script)
        command -v docker >/dev/null 2>&1 && status="OK" details="docker present" || status="MISSING" details="docker not found in PATH"
        ;;

      nvm)
        if [[ -z "${target_home}" ]]; then
          status="MISSING"
          details="Cannot determine target home for ${target_user}"
        elif [[ ! -d "${target_home}/.nvm" ]]; then
          status="MISSING"
          details="nvm not found at ${target_home}/.nvm"
        else
          if sudo -u "${target_user}" bash -lc 'set -euo pipefail; export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"; command -v node >/dev/null; command -v npm >/dev/null; node -v >/dev/null; npm -v >/dev/null'; then
            status="OK"
            details="nvm ok; node/npm available"
          else
            status="MISSING"
            details="nvm present but node/npm not usable for ${target_user}"
          fi
        fi
        ;;

      *)
        status="UNKNOWN"
        details="No test handler for strategy '${strategy}'"
        ;;
    esac

    [[ "${status}" == "OK" ]] || failures=$((failures + 1))

    printf '%-18s  %-14s  %-10s  %s\n' \
      "${key}" "${strategy}" "${status}" "${details} | ${label}" >>"${out_file}"
  done

  # Footer
  {
    printf '\n'
    printf 'Summary\n'
    printf 'Selected apps : %s\n' "${#selected_keys[@]}"
    printf 'Failures      : %s\n' "${failures}"
    printf 'Overall       : %s\n' "$([[ "${failures}" -eq 0 ]] && echo "PASS" || echo "FAIL")"
    printf '\n'
    printf 'Report saved  : %s\n' "${out_file}"
  } >>"${out_file}"

  _app_test_show_dialog "${out_file}" "App install status"
  return 0
}

