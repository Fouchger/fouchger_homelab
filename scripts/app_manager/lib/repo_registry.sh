#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/repo_registry.sh
# Created: 29/01/2026
# Updated: 29/01/2026
# Description: Repo artefact registry to prevent breaking shared APT repos on uninstall.
#
# Notes
#   - Only remove a repo's list/keyring when no selected apps still use it.
#   - This is computed from:
#       * APP_SELECTION (desired ON/OFF)
#       * APP_CATALOGUE (strategy per app)
#   - strategies.sh calls repo_registry_should_remove <strategy> if present.
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

declare -gA REPO_STRATEGY_USE_COUNT=()

repo_registry_init() { REPO_STRATEGY_USE_COUNT=(); }

repo_registry_strategy_is_repo() {
  local s="$1"
  case "$s" in
    github_cli_repo|hashicorp_repo|docker_apt_repo|grafana_repo|mongodb_repo) return 0 ;;
    *) return 1 ;;
  esac
}

repo_registry_compute_from_catalogue() {
  repo_registry_init
  local row type key _label _def _packages _desc strategy _ver
  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key _label _def _packages _desc strategy _ver <<< "$row" || true
    [[ "$type" == "APP" ]] || continue
    repo_registry_strategy_is_repo "$strategy" || continue
    if [[ "${APP_SELECTION[$key]:-OFF}" == "ON" ]]; then
      REPO_STRATEGY_USE_COUNT["$strategy"]=$(( ${REPO_STRATEGY_USE_COUNT["$strategy"]:-0} + 1 ))
    fi
  done
}

repo_registry_should_remove() {
  local strategy="$1"
  repo_registry_strategy_is_repo "$strategy" || return 0
  local count="${REPO_STRATEGY_USE_COUNT[$strategy]:-0}"
  (( count == 0 ))
}
