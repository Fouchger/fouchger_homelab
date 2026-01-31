#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/diagnostics.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Command entrypoint (diagnostics).
# Purpose: Implements one discrete action invoked by homelab.sh or the menu.
# Usage:
#   ./commands/diagnostics.sh
# Prerequisites:
#   - Project bootstrapped (see bootstrap.sh)
# Notes:
#   - Sprint 2 delivers read-only diagnostics only (no infra changes).
#   - This script follows the command runner contract in lib/command_runner.sh.
# -----------------------------------------------------------------------------

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/command_runner.sh"

diagnostics_impl() {
  # Read-only diagnostics view.
  # This is safe to call either via command_run or directly from the menu.

  # Best-effort environment context (do not assume runtime vars exist).
  local run_id run_dir log_file started
  run_id="${RUN_ID:-""}"
  run_dir="${RUN_DIR:-""}"
  log_file="${LOG_FILE:-""}"
  started="${RUN_STARTED_AT:-""}"

  local latest_env
  latest_env="${STATE_RUNS_DIR:-${ROOT_DIR}/state/runs}/latest.env"

  local latest_preview="(missing)"
  if [[ -f "${latest_env}" ]]; then
    # Show only safe keys. Do not display any secrets even if present.
    latest_preview=$(grep -E '^(RUN_ID|RUN_DIR|LOG_FILE|RUN_STARTED_AT)=' "${latest_env}" 2>/dev/null || true)
    [[ -n "${latest_preview}" ]] || latest_preview="(empty)"
  fi

  # Gate status (Sprint 2: minimal gates only).
  local gate_secrets="unknown"
  if [[ -n "${log_file}" ]] && [[ -f "${log_file}" ]] && declare -F validate_no_secrets_leaked >/dev/null 2>&1; then
    if validate_no_secrets_leaked "${log_file}"; then
      gate_secrets="pass"
    else
      gate_secrets="fail"
    fi
  fi

  local text
  text=$(
    cat <<EOF
Runtime state
  RUN_ID: ${run_id:-"(not set)"}
  RUN_DIR: ${run_dir:-"(not set)"}
  LOG_FILE: ${log_file:-"(not set)"}
  Started: ${started:-"(not set)"}

Environment
  ROOT_DIR: ${ROOT_DIR}
  IS_TTY: ${IS_TTY:-"(unknown)"}
  UI_MODE: ${UI_MODE:-"(unknown)"}
  HOMELAB_UI_MODE: ${HOMELAB_UI_MODE:-"(unset)"}
  HOMELAB_LOG_LEVEL: ${HOMELAB_LOG_LEVEL:-"(unset)"}

Gates
  no_secrets_leaked: ${gate_secrets}

state/runs/latest.env
${latest_preview}
EOF
  )

  log_info "Diagnostics opened" || true
  runtime_summary_line "diagnostics viewed" || true

  ui_info "Diagnostics" "${text}"
  return 0
}

main() {
  command_run "diagnostics" diagnostics_impl "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
