#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/logging.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description:
#   System-wide logging with configurable levels and a helper to run commands.
#
# Behaviour:
#   - Default LOG_LEVEL is INFO.
#   - DEBUG: do not suppress command output; behave like running directly.
#   - INFO/WARN/ERROR: only emit explicit log lines; command output is captured
#     to a log file unless you choose to surface it.
#
# Notes:
#   - This library does not change caller shell options.
#   - Colour output is best-effort and only when stdout is a TTY.
# -----------------------------------------------------------------------------

# Guardrail: prevent double-sourcing.
if [[ -n "${_HOMELAB_LOGGING_SOURCED:-}" ]]; then
  return 0
fi
readonly _HOMELAB_LOGGING_SOURCED="1"

homelab_log__supports_color() {
  [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]
}

homelab_log__level_num() {
  case "${1^^}" in
    DEBUG) echo 10 ;;
    INFO)  echo 20 ;;
    WARN|WARNING) echo 30 ;;
    ERROR) echo 40 ;;
    *) echo 20 ;;
  esac
}

homelab_log__now() {
  # ISO-8601-ish, local time.
  date '+%Y-%m-%d %H:%M:%S'
}

homelab_log__default_log_file() {
  local base
  base="${XDG_STATE_HOME:-$HOME/.local/state}"
  if [[ -z "${base:-}" || ! -d "${base%/}" ]]; then
    base="/tmp"
  fi
  echo "${base%/}/fouchger_homelab_back_to_basic/homelab.log"
}

homelab_log_init() {
  LOG_LEVEL="${LOG_LEVEL:-INFO}"
  LOG_LEVEL="${LOG_LEVEL^^}"
  export LOG_LEVEL

  HOMELAB_LOG_FILE="${HOMELAB_LOG_FILE:-}"
  if [[ -z "${HOMELAB_LOG_FILE}" ]]; then
    HOMELAB_LOG_FILE="$(homelab_log__default_log_file)"
  fi
  export HOMELAB_LOG_FILE

  local dir
  dir="$(dirname -- "$HOMELAB_LOG_FILE")"
  mkdir -p "$dir" 2>/dev/null || true
}

homelab_log__emit() {
  local level="$1"; shift
  local msg="$*"

  local current target
  current="$(homelab_log__level_num "${LOG_LEVEL:-INFO}")"
  target="$(homelab_log__level_num "$level")"
  (( target < current )) && return 0

  local ts
  ts="$(homelab_log__now)"

  local prefix="[$ts] [$level]"

  if homelab_log__supports_color; then
    # Reuse palette variables if ui.sh is loaded; otherwise fall back.
    local c_reset c_level
    c_reset="${RESET:-$'\033[0m'}"
    case "$level" in
      DEBUG) c_level="${C_MUTED:-$'\033[2m'}" ;;
      INFO) c_level="${C_INFO:-$'\033[36m'}" ;;
      WARN) c_level="${C_WARN:-$'\033[33m'}" ;;
      ERROR) c_level="${C_ERROR:-$'\033[31m'}" ;;
      SUCCESS) c_level="${C_SUCCESS:-$'\033[32m'}" ;;
      *) c_level="" ;;
    esac
    printf '%b%s%b %s\n' "$c_level" "$prefix" "$c_reset" "$msg" >&2
  else
    printf '%s %s\n' "$prefix" "$msg" >&2
  fi
}

log_debug()   { homelab_log__emit "DEBUG"   "$@"; }
log_info()    { homelab_log__emit "INFO"    "$@"; }
log_warn()    { homelab_log__emit "WARN"    "$@"; }
log_error()   { homelab_log__emit "ERROR"   "$@"; }
log_success() { homelab_log__emit "SUCCESS" "$@"; }

homelab_run_cmd() {
  # Usage:
  #   homelab_run_cmd "Human description" command arg...
  #
  # DEBUG: run with output passthrough.
  # Others: capture output to HOMELAB_LOG_FILE and only emit explicit logs.

  local desc="$1"; shift
  local -a cmd=("$@")

  homelab_log_init

  if [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
    log_debug "$desc"
    "${cmd[@]}"
    return $?
  fi

  # Capture output
  local tmp
  tmp="${HOMELAB_LOG_FILE}.tmp.$$"

  log_info "$desc"
  if "${cmd[@]}" >"$tmp" 2>&1; then
    cat "$tmp" >>"$HOMELAB_LOG_FILE" 2>/dev/null || true
    rm -f "$tmp" 2>/dev/null || true
    log_success "Done"
    return 0
  fi

  local rc=$?
  {
    echo "--- $(homelab_log__now) ---"
    echo "Command failed (exit $rc): ${cmd[*]}"
    cat "$tmp"
  } >>"$HOMELAB_LOG_FILE" 2>/dev/null || true

  # Surface a small tail for quick diagnosis.
  log_error "Failed (exit $rc). See log: $HOMELAB_LOG_FILE"
  if [[ -s "$tmp" ]]; then
    log_error "Last output:"
    tail -n 20 "$tmp" >&2 || true
  fi
  rm -f "$tmp" 2>/dev/null || true
  return "$rc"
}
