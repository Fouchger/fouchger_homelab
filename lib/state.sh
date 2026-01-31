#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/state.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: State file helpers (selections.env and latest.env handoff).
# Purpose: Provide a single place to load/save non-secret runtime selections.
# Usage:
#   source "${ROOT_DIR}/lib/state.sh"
#   state_selections_load
#   state_selections_set_profile "development" "replace"
#   state_selections_save
# Notes:
#   - state/selections.env stores user choices (non-secret) across runs.
#   - state/runs/latest.env is per-run handoff written by lib/runtime.sh.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

STATE_SELECTIONS_FILE=""
SELECTED_PROFILE=""
SELECTED_APPS_INSTALL=""
SELECTED_APPS_UNINSTALL=""

state__require_env() {
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/env.sh"
  env_init
  STATE_SELECTIONS_FILE="${STATE_DIR}/selections.env"
}

state__csv_normalise() {
  # Normalise comma-separated list: trim spaces, remove empty, de-dup, stable sort.
  local csv="${1:-}"
  python3 - <<'PY' "$csv"
import sys
raw = sys.argv[1]
items = [x.strip() for x in raw.split(',') if x.strip()]
seen = set()
out = []
for x in items:
    if x not in seen:
        seen.add(x)
        out.append(x)
print(','.join(out))
PY
}

state__csv_merge() {
  local base="${1:-}" add="${2:-}"
  state__csv_normalise "${base},${add}"
}

state_selections_load() {
  state__require_env
  if [[ -f "${STATE_SELECTIONS_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${STATE_SELECTIONS_FILE}"
  fi

  SELECTED_PROFILE="${SELECTED_PROFILE:-}"
  SELECTED_APPS_INSTALL="${SELECTED_APPS_INSTALL:-}"
  SELECTED_APPS_UNINSTALL="${SELECTED_APPS_UNINSTALL:-}"
}

state_selections_save() {
  state__require_env
  umask 077
  {
    echo "# fouchger_homelab selections (non-secret)"
    echo "# Updated: $(date -Iseconds)"
    echo "SELECTED_PROFILE=${SELECTED_PROFILE}"
    echo "SELECTED_APPS_INSTALL=${SELECTED_APPS_INSTALL}"
    echo "SELECTED_APPS_UNINSTALL=${SELECTED_APPS_UNINSTALL}"
  } >"${STATE_SELECTIONS_FILE}"
}

state_selections_set_profile() {
  local profile mode apps_csv
  profile="$1"; mode="${2:-replace}"
  apps_csv="${3:-}"
  SELECTED_PROFILE="${profile}"
  case "${mode}" in
    add)
      SELECTED_APPS_INSTALL="$(state__csv_merge "${SELECTED_APPS_INSTALL}" "${apps_csv}")"
      ;;
    replace|*)
      SELECTED_APPS_INSTALL="$(state__csv_normalise "${apps_csv}")"
      ;;
  esac
}

state_selections_set_manual() {
  local install_csv uninstall_csv
  install_csv="${1:-}"; uninstall_csv="${2:-}"
  SELECTED_APPS_INSTALL="$(state__csv_normalise "${install_csv}")"
  SELECTED_APPS_UNINSTALL="$(state__csv_normalise "${uninstall_csv}")"
}
