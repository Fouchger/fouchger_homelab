#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/installer.sh
# Created: 29/01/2026
# Updated: 29/01/2026
# Description: Orchestrates install/uninstall based on desired selections.
#
# Notes
#   - Desired selection model:
#       ON  -> install (ensure present)
#       OFF -> uninstall (ensure removed)
#   - Validates required env vars per strategy on install.
#   - Uses repo_registry to avoid removing shared repos while still in use.
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"

# shellcheck disable=SC1090
source "$REPO_ROOT/scripts/app_manager/lib/app_catalogue.sh"
# shellcheck disable=SC1090
source "$REPO_ROOT/scripts/app_manager/lib/selection.sh"
# shellcheck disable=SC1090
source "$REPO_ROOT/scripts/app_manager/lib/repo_registry.sh"
# shellcheck disable=SC1090
source "$REPO_ROOT/scripts/app_manager/lib/strategies.sh"

main() {
  app_selection_load
  repo_registry_compute_from_catalogue

  local ok=0 fail=0
  local failures=()

  local row type key label _def packages _desc strategy ver
  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label _def packages _desc strategy ver <<< "$row" || true
    [[ "$type" == "APP" ]] || continue

    local desired="${APP_SELECTION[$key]:-OFF}"
    local mode="uninstall"; [[ "$desired" == "ON" ]] && mode="install"

    if [[ "$mode" == "install" ]]; then
      if ! strategy_requires_env "$strategy" "$key" "$ver"; then
        failures+=("$key|$label|missing env for $strategy")
        fail=$((fail+1))
        continue
      fi
    fi

    if strategy_apply "$mode" "$key" "$packages" "$strategy" "$ver"; then
      ok=$((ok+1))
    else
      failures+=("$key|$label|$mode failed")
      fail=$((fail+1))
    fi
  done

  printf '\n%s\n' "App Manager Summary"
  printf '%s\n' "OK: $ok"
  printf '%s\n' "Failed: $fail"
  printf '%s\n' "Selection file: $(app_selection_file)"

  if (( ${#failures[@]} > 0 )); then
    printf '\nFailures:\n'
    for f in "${failures[@]}"; do
      IFS='|' read -r k l m <<< "$f" || true
      printf '  - %s (%s): %s\n' "$k" "$l" "$m"
    done
    return 1
  fi
}

main
