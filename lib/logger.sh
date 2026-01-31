#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/logger.sh
# Created: 2026-01-30
# Updated: 2026-01-30
# Description: Logging helpers with levels, colour, emojis, and secret redaction.
# Purpose: Provide consistent, readable logs for both interactive and dialog runs.
# Usage:
#   source "${ROOT_DIR}/lib/logger.sh"
#   logger_init "${LOG_FILE}" "INFO"
#   log_info "Hello"
# Prerequisites:
#   - bash >= 4
#   - coreutils (date)
# Notes:
#   - Never log secret values. This logger redacts common secret patterns and
#     optionally redacts values from environment variables.
#   - Console output is written to stderr to preserve stdout for data piping.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

LOGGER_LEVEL="INFO"
LOGGER_LOG_FILE=""
LOGGER_COLOUR=1
LOGGER_EMOJI=1
LOGGER_REDACT_VALUES=()

logger_level_to_int() {
  case "${1^^}" in
    DEBUG) echo 10 ;;
    INFO)  echo 20 ;;
    WARN|WARNING) echo 30 ;;
    ERROR) echo 40 ;;
    *) echo 20 ;;
  esac
}

logger_should_log() {
  local current target
  current="$(logger_level_to_int "${LOGGER_LEVEL}")"
  target="$(logger_level_to_int "$1")"
  (( target >= current ))
}

logger_enable_colour() {
  # Enable colour only for TTY. Dialog typically runs in a TTY but captures; we
  # allow colour unless explicitly disabled.
  if [[ -t 2 ]]; then
    LOGGER_COLOUR=1
  else
    LOGGER_COLOUR=0
  fi
}

logger_add_redact_value() {
  # Add a literal value to redact (exact match replacements in output).
  # Avoid adding empty values.
  local val
  val="${1:-}"
  [[ -n "$val" ]] && LOGGER_REDACT_VALUES+=("$val")
}

logger_seed_redactions_from_env() {
  # Pull typical secret-like env vars into redact list.
  local k
  for k in $(compgen -e); do
    case "${k^^}" in
      *TOKEN*|*SECRET*|*PASSWORD*|*PASS*|*API_KEY*|*ACCESS_KEY*|*PRIVATE_KEY*)
        logger_add_redact_value "${!k:-}"
        ;;
    esac
  done
}

logger_redact() {
  # Redact common secret patterns and any seeded secret values.
  local s
  s="$1"

  # Redact well-known key/value formats
  s="${s//password=/password=***}"
  s="${s//passwd=/passwd=***}"
  s="${s//token=/token=***}"
  s="${s//secret=/secret=***}"
  s="${s//api_key=/api_key=***}"

  # Redact bearer style
  s="${s//Bearer /Bearer ***}"

  # Redact any known secret values
  local v
  for v in "${LOGGER_REDACT_VALUES[@]:-}"; do
    [[ -n "$v" ]] && s="${s//${v}/***}"
  done

  printf '%s' "$s"
}

logger_init() {
  # Args: log_file, level
  LOGGER_LOG_FILE="$1"
  LOGGER_LEVEL="${2:-INFO}"

  logger_enable_colour
  logger_seed_redactions_from_env

  # Ensure log file exists
  mkdir -p "$(dirname "${LOGGER_LOG_FILE}")"
  : >"${LOGGER_LOG_FILE}"
}

logger_fmt_ts() {
  date '+%Y-%m-%d %H:%M:%S'
}

logger_colour() {
  local code="$1"
  local text="$2"
  if (( LOGGER_COLOUR )); then
    printf '\033[%sm%s\033[0m' "$code" "$text"
  else
    printf '%s' "$text"
  fi
}

logger_prefix() {
  local lvl="$1"
  local emoji="$2"
  local tag
  tag="[$(logger_fmt_ts)] [$lvl]"

  if (( LOGGER_EMOJI )); then
    printf '%s %s' "$emoji" "$tag"
  else
    printf '%s' "$tag"
  fi
}

logger_write() {
  # Args: level, emoji, colour_code, message
  local lvl emoji colour_code msg line
  lvl="$1"; emoji="$2"; colour_code="$3"; msg="$4"

  logger_should_log "$lvl" || return 0

  msg="$(logger_redact "$msg")"
  line="$(logger_prefix "$lvl" "$emoji") $msg"

  # Write to console (stderr) and to log file.
  if (( LOGGER_COLOUR )); then
    printf '%s\n' "$(logger_colour "$colour_code" "$line")" >&2
  else
    printf '%s\n' "$line" >&2
  fi
  printf '%s\n' "$line" >>"${LOGGER_LOG_FILE}"
}

log_debug() { logger_write "DEBUG" "🧪" "36" "$*"; }
log_info()  { logger_write "INFO"  "ℹ️" "32" "$*"; }
log_warn()  { logger_write "WARN"  "⚠️" "33" "$*"; }
log_error() { logger_write "ERROR" "❌" "31" "$*"; }

log_section() {
  # Visual separator to improve readability.
  log_info ""
  log_info "==================== $* ===================="
}

log_cmd() {
  # Run a command, stream its output, and capture return code.
  # Usage: log_cmd "description" -- command args...
  local desc rc
  desc="$1"; shift

  log_info "▶️  $desc"

  # Stream output to stderr and log file while redacting.
  # We avoid 'set -e' termination by capturing rc.
  set +o errexit
  "$@" 2>&1 | while IFS= read -r line; do
    line="$(logger_redact "$line")"
    printf '%s\n' "$line" >&2
    printf '%s\n' "$line" >>"${LOGGER_LOG_FILE}"
  done
  rc=${PIPESTATUS[0]}
  set -o errexit

  if (( rc == 0 )); then
    log_info "✅ Completed: $desc"
  else
    log_error "🧨 Failed: $desc (rc=$rc)"
  fi

  return "$rc"
}
