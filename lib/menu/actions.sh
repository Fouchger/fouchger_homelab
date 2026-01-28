#!/usr/bin/env bash
# =============================================================================
# Filename: lib/actions.sh
# Description: Operational orchestration for menus (called by lib/menu.sh)
#
# Responsibilities
#   - Source optional feature modules (best-effort)
#   - Guardrails: ensure required functions exist before calling
#   - Provide action_* wrappers used by menu routing
#
# Notes
#   - Avoid placing dialog UI menu structure here. Keep that in lib/menu.sh
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# REPO_ROOT is defined in bin/homelab before sourcing this file.
: "${REPO_ROOT:?REPO_ROOT must be set before sourcing lib/actions.sh}"

source_if_exists() {
  local f="$1"
  [[ -f "${f}" ]] && source "${f}"
}

require_function() {
  # Usage: require_function func_name "friendly label"
  local fn="$1" label="${2:-$1}"
  if ! declare -F "${fn}" >/dev/null 2>&1; then
    ui_msgbox "Missing function" \
      "The menu item '${label}' is not available.\n\nExpected function:\n  ${fn}\n\nCheck that the relevant script is sourced."
    return 1
  fi
  return 0
}

# # Load optional modules once at import time
# homelab_load_modules

# -----------------------------------------------------------------------------
# Action wrappers called by menus
# -----------------------------------------------------------------------------

action_open_proxmox_templates() {
  require_function "proxmox_templates_menu" "Proxmox templates" || return 0
  proxmox_templates_menu
}

action_open_mikrotik_menu() {
  require_function "mikrotik_menu" "MikroTik integration" || return 0
  mikrotik_menu
}

action_open_dns_menu() {
  require_function "dns_menu" "DNS services" || return 0
  dns_menu
}

action_run_questionnaires() {
  require_function "run_questionnaires" "Run questionnaires" || return 0
  run_questionnaires
}

action_validate_configuration() {
  # Run validation with live output so operators can see progress, and avoid
  # ANSI escapes appearing when output is captured/rendered in dialog.
  local rc_file rc
  rc_file="$(ui_tmpfile validate_configuration_rc)"

  ui_programbox \
    "Validate configuration" \
    "NO_COLOR=1 \"${REPO_ROOT}/scripts/core/validate.sh\"" \
    "${rc_file}"

  rc="$(cat "${rc_file}" 2>/dev/null || echo 0)"
  rm -f -- "${rc_file}" || true

  if [[ "${rc}" == "0" ]]; then
    ui_msgbox "Validation" "Completed successfully."
  else
    ui_msgbox "Validation" "Completed with issues (exit code ${rc}).\n\nReview the run log for details."
  fi
  return 0
}


action_open_app_manager() {
  # Keep the messaging consistent and centralised here.
  if ! require_function "app_manager_menu" "App Manager (LXC tools)"; then
    ui_msgbox "Not wired yet" \
      "App Manager submenu is not wired in this entrypoint.\n\nIf you have the App Manager functions available (profiles, checklist, apply, pins), expose them as:\n  app_manager_menu\n\nOr source the script that defines them in lib/actions.sh (homelab_load_modules)."
    return 0
  fi
  app_manager_menu
}
