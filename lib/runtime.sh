#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/runtime.sh
# Created: 2026-01-30
# Updated: 2026-01-30
# Description: Run lifecycle orchestration (RUN_ID, paths, traps, summaries).
# Purpose: Ensure every execution has a predictable context and artefact trail.
# Usage:
#   source "${ROOT_DIR}/lib/runtime.sh"
#   runtime_init
#   # ... work ...
#   runtime_finish 0
# Prerequisites:
#   - bash >= 4
#   - lib/env.sh, lib/logger.sh, lib/validation.sh
# Notes:
#   - Creates RUN_ID and a per-run directory under state/runs.
#   - Writes state/runs/latest.env for convenience.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

# These are set during runtime_init
RUN_ID=""
RUN_DIR=""
RUN_STARTED_AT=""
RUN_TIMESTAMP=""
RUN_EXIT_CODE=0
RUN_FINISHED=0

runtime_latest__file() {
  echo "${STATE_RUNS_DIR}/latest.env"
}

runtime_latest_upsert() {
  # Upsert a key=value into state/runs/latest.env.
  # This file is the non-secret handoff contract between pipeline steps.
  local key value file tmp
  key="${1:-}"; value="${2:-}"
  [[ -n "${key}" ]] || return 1
  file="$(runtime_latest__file)"

  mkdir -p "$(dirname "${file}")" || true
  touch "${file}" || true

  tmp="${file}.tmp"
  if grep -qE "^${key}=" "${file}" 2>/dev/null; then
    # Replace existing
    sed -E "s|^${key}=.*|${key}=${value}|" "${file}" >"${tmp}"
  else
    cat "${file}" >"${tmp}"
    printf '%s=%s\n' "${key}" "${value}" >>"${tmp}"
  fi
  mv "${tmp}" "${file}"
}

runtime__require_root_dir() {
  if [[ -z "${ROOT_DIR:-}" ]]; then
    # Attempt best-effort detection if caller forgot.
    # shellcheck disable=SC1091
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/env.sh"
    env_detect_root_dir
  fi
}

runtime__now_compact() {
  date '+%Y%m%dT%H%M%S'
}

runtime__make_run_id() {
  # RUN_ID format: YYYYMMDDTHHMMSS-<pid>-<random>
  local ts rnd
  ts="$(runtime__now_compact)"
  rnd="$(LC_ALL=C tr -dc 'a-f0-9' </dev/urandom | head -c 6 || true)"
  echo "${ts}-$$-${rnd}"
}

runtime__rotate_logs_keep_5() {
  # Keep the most recent 5 log files matching homelab_*.log in state/logs.
  local dir pattern
  dir="$1"
  pattern='homelab_*.log'

  local files
  mapfile -t files < <(ls -1t "${dir}/${pattern}" 2>/dev/null || true)

  local i
  for ((i=5; i<${#files[@]}; i++)); do
    rm -f "${files[$i]}" || true
  done
}

runtime_init() {
  runtime__require_root_dir

  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/env.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/config.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/logger.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/validation.sh"

  env_init

  # Load non-secret settings (single source of truth for config precedence).
  config_load_all

  RUN_ID="$(runtime__make_run_id)"
  export RUN_ID
  RUN_STARTED_AT="$(date -Iseconds)"
  export RUN_STARTED_AT
  RUN_TIMESTAMP="${RUN_STARTED_AT}"
  export RUN_TIMESTAMP

  RUN_DIR="${STATE_RUNS_DIR}/${RUN_ID}"
  export RUN_DIR
  mkdir -p "${RUN_DIR}"

  # Log file with timestamp in filename.
  local log_file
  log_file="${STATE_LOGS_DIR}/homelab_${RUN_ID}.log"
  export LOG_FILE="${log_file}"

  runtime__rotate_logs_keep_5 "${STATE_LOGS_DIR}"

  logger_init "${LOG_FILE}" "${HOMELAB_LOG_LEVEL:-INFO}"

  # Persist latest run pointer.
  {
    echo "RUN_ID=${RUN_ID}"
    echo "RUN_DIR=${RUN_DIR}"
    echo "LOG_FILE=${LOG_FILE}"
    echo "RUN_STARTED_AT=${RUN_STARTED_AT}"
    echo "RUN_TIMESTAMP=${RUN_TIMESTAMP}"
    echo "DRY_RUN=${DRY_RUN:-false}"
  } >"${STATE_RUNS_DIR}/latest.env"

  log_info "🚀 Run started" "run_id=${RUN_ID}" "log=${LOG_FILE}"

  # Register exit trap once per shell.
  trap 'runtime_finish $?' EXIT
}

runtime_summary_line() {
  # Append a short, human-readable line to the run summary.
  # This is safe to call before runtime_finish.
  local msg
  msg="$*"
  [[ -n "${RUN_DIR:-}" ]] || return 0
  printf '%s\n' "${msg}" >>"${RUN_DIR}/summary_lines.txt"
}

runtime_finish() {
  # Called via trap; safe to call multiple times.
  local code
  code="$1"

  # Prevent re-entrancy (explicit runtime_finish + EXIT trap, or nested exits).
  if [[ "${RUN_FINISHED}" -eq 1 ]]; then
    return 0
  fi
  RUN_FINISHED=1
  RUN_EXIT_CODE="${code}"

  local ended
  ended="$(date -Iseconds)"

  local summary
  summary="${RUN_DIR}/summary.txt"

  {
    echo "fouchger_homelab run summary"
    echo "RUN_ID: ${RUN_ID}"
    echo "Started: ${RUN_STARTED_AT}"
    echo "Ended: ${ended}"
    echo "Exit code: ${code}"
    echo "Log file: ${LOG_FILE}"

    if [[ -f "${RUN_DIR}/summary_lines.txt" ]]; then
      echo ""
      echo "Notes:"
      sed 's/^/ - /' "${RUN_DIR}/summary_lines.txt" || true
    fi
  } >"${summary}"

  # Validate that we have not leaked secrets in the log.
  if validate_no_secrets_leaked "${LOG_FILE}"; then
    log_info "✅ No secrets detected in logs" "summary=${summary}"
  else
    log_error "🛑 Potential secret leak detected in logs" "summary=${summary}"
    # Do not overwrite the original exit code, but flag via stderr.
  fi

  if [[ "${code}" -eq 0 ]]; then
    log_info "🏁 Run completed successfully" "summary=${summary}"
  else
    log_warn "⚠️ Run completed with errors" "exit=${code}" "summary=${summary}"
  fi
}
