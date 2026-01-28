#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/apply.sh
# Purpose : Apply selections (install/uninstall) based on env + catalogue.
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

apply_changes() {
  if ! ui_confirm "Apply Changes" "This will install selected apps.\nIt will remove only apps that were installed by this manager.\n\nProceed?"; then
    return 0
  fi

  apm_init_paths

  # Layer 1 logging only (structured operator log)
  logging_set_layer1_file "${LOG_FILE}"

  info "Apply started. Log file: ${LOG_FILE}"

  ensure_pkg_mgr
  pkg_update_once
  load_env || true

  local row type key label def pkgs_csv desc strategy version_var
  local -a apt_install_list=()
  local need_hashicorp_repo=0

  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    validate_key "${key}" || continue
    strategy="${strategy:-apt}"

    if [[ "$(get_selection_value "${key}")" == "1" ]]; then
      case "${strategy}" in
        apt|hashicorp_repo)
          [[ "${strategy}" == "hashicorp_repo" ]] && need_hashicorp_repo=1
          local -a pkgs_arr=()
          pkgs_csv_to_array "${pkgs_csv}" pkgs_arr
          ((${#pkgs_arr[@]})) && apt_install_list+=("${pkgs_arr[@]}")
          ;;
      esac
    fi
  done

  if [[ "${need_hashicorp_repo}" -eq 1 ]]; then
    info "HashiCorp repo required. Ensuring repo is configured."
    ensure_hashicorp_repo
    pkg_update_once
  fi

  local -a apt_install_unique=()
  unique_pkgs apt_install_list apt_install_unique

  local -a apt_install_final=()
  local -a apt_missing=()
  filter_installable_apt_pkgs apt_install_unique apt_install_final apt_missing

  if ((${#apt_missing[@]})); then
    warn "Skipping missing apt packages: ${apt_missing[*]}"
    ui_msgbox "Skipped packages" "These packages are not available from current apt sources and were skipped:\n\n${apt_missing[*]}\n\nTip: Some items need a vendor repo or a binary install strategy."
  fi

  if ((${#apt_install_final[@]})); then
    info "Installing (apt/${PKG_MGR}) count=${#apt_install_final[@]}"
    pkg_install_pkgs "${apt_install_final[@]}"
  else
    info "No apt packages selected for installation."
  fi

  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    validate_key "${key}" || continue
    strategy="${strategy:-apt}"

    if [[ "$(get_selection_value "${key}")" == "1" ]]; then
      case "${strategy}" in
        apt|hashicorp_repo)
          if [[ -n "${pkgs_csv}" ]] && verify_pkgs_installed "${pkgs_csv}"; then
            mark_installed "${key}" "${strategy}" "${pkgs_csv}"
            ok "Marked installed: ${key}"
          else
            warn "Not marking ${key}; packages not fully installed: ${pkgs_csv}"
          fi
          ;;
      esac
    fi
  done

  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    validate_key "${key}" || continue
    strategy="${strategy:-apt}"

    case "${strategy}" in
      python|binary|docker_script)
        if [[ "$(get_selection_value "${key}")" == "1" ]]; then
          info "Installing (${strategy}): ${key}"
          install_by_strategy "${key}" "${pkgs_csv}" "${strategy}"
          mark_installed "${key}" "${strategy}" "${pkgs_csv}"
          ok "Installed: ${key}"
        else
          info "Removing (${strategy}): ${key}"
          remove_by_strategy "${key}" "${pkgs_csv}" "${strategy}"
        fi
        ;;
      apt|hashicorp_repo)
        if [[ "$(get_selection_value "${key}")" != "1" ]] && is_marked_installed "${key}"; then
          info "Removing (conservative ${strategy}): ${key}"
          remove_by_strategy "${key}" "${pkgs_csv}" "${strategy}"
        fi
        ;;
    esac
  done

  info "Autoremove via ${PKG_MGR}"
  pkg_autoremove

  audit_selected_apps || true
  ok "Apply complete."
  ui_msgbox "Complete" "Install / uninstall complete.\n\nLog:\n${LOG_FILE}"
}

