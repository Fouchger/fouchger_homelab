#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/run.sh
# Created: 2026-01-18
# Description: Run initialisation (log file per run, traps, diagnostics).
# Usage:
#   source "${REPO_ROOT}/lib/run.sh"
#   run_init "component-name"
# Developer notes:
#   - The log capture uses tee. When stdout is redirected, the caller may choose
#     to disable tee by setting HOMELAB_NO_TEE=1.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

# Defensive sourcing: allow callers to source lib/run.sh directly.
# Prefer repo helpers if they are not already loaded.
if ! declare -F ensure_dirs >/dev/null 2>&1 || [[ -z "${LOG_DIR_DEFAULT:-}" ]]; then
  # shellcheck source=lib/paths.sh
  source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/paths.sh"
fi

if ! declare -F logging_set_layer1_file >/dev/null 2>&1; then
  # shellcheck source=lib/logging.sh
  source "${REPO_ROOT}/lib/logging.sh"
fi

RUN_ID=""
RUN_LOG_FILE=""

run_init() {
  local component ts
  component="${1:-run}"
  ensure_dirs

  ts="$(date +%Y%m%d-%H%M%S)"
  RUN_ID="${ts}-${component}"
  RUN_LOG_FILE="${LOG_DIR_DEFAULT}/${RUN_ID}.log"

  # Ensure log file path exists
  mkdir -p "$(dirname "$RUN_LOG_FILE")" >/dev/null 2>&1 || true
  : >"$RUN_LOG_FILE" 2>/dev/null || true

  # Layer 1 structured log always writes here (plain text)
  logging_set_layer1_file "$RUN_LOG_FILE"

  # Optional: also capture full stdout/stderr into the same file.
  # Only tee when stdout is a real TTY to avoid dialog/process-substitution issues.
  if [[ -z "${HOMELAB_NO_TEE:-}" ]]; then
    if [[ -t 1 ]]; then
      exec > >(tee -a "$RUN_LOG_FILE") 2>&1
    else
      exec >>"$RUN_LOG_FILE" 2>&1
    fi
  else
    exec >>"$RUN_LOG_FILE" 2>&1
  fi

  info "Run started: ${RUN_ID}"
  info "Log file: ${RUN_LOG_FILE}"

  trap 'run_on_error $? $LINENO' ERR
  trap 'run_on_exit' EXIT
}


run_on_error() {
  local code line
  code="$1"; line="$2"
  error "Run failed (exit ${code}) at line ${line}. See log: ${RUN_LOG_FILE}"
}

run_on_exit() {
  local code
  code="$?"
  if [ "$code" -eq 0 ]; then
    ok "Run completed successfully."
  fi
}