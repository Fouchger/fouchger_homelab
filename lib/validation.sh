#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/validation.sh
# Created: 2026-01-30
# Updated: 2026-01-30
# Description: Lightweight validation gates for runtime and safety checks.
# Purpose: Provide repeatable checks for environment readiness and guardrails.
# Usage:
#   source "${ROOT_DIR}/lib/validation.sh"
#   validate_no_secrets_leaked "${LOG_FILE}" (returns 0 if ok)
# Prerequisites:
#   - bash >= 4
# Notes:
#   - Sprint 1 focuses on the acceptance criteria (RUN_ID, logs, no secrets).
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

validation__seed_secret_values() {
  # Collect potential secret values from environment to scan for in log files.
  # Also scan state/secrets.env if present (without printing values).
  local vals=()
  local k
  for k in $(compgen -e); do
    case "${k^^}" in
      *TOKEN*|*SECRET*|*PASSWORD*|*PASS*|*API_KEY*|*ACCESS_KEY*|*PRIVATE_KEY*)
        [[ -n "${!k:-}" ]] && vals+=("${!k}")
        ;;
    esac
  done
  printf '%s\n' "${vals[@]:-}"
}

validation__seed_secrets_from_file() {
  local f
  f="${STATE_DIR:-${ROOT_DIR:-}/state}/secrets.env"

  [[ -f "${f}" ]] || return 0

  # Parse KEY=VALUE lines, ignore comments and blanks. Do not emit keys.
  # We only output values for internal scanning.
  awk -F'=' '
    /^[[:space:]]*#/ {next}
    /^[[:space:]]*$/ {next}
    NF>=2 {sub(/^[[:space:]]+/,"",$2); sub(/[[:space:]]+$/,"",$2); print $2}
  ' "${f}" 2>/dev/null || true
}

validate_no_secrets_leaked() {
  # Returns 0 if log looks clean, 1 if any known secret value is found.
  local log_file
  log_file="$1"

  [[ -f "${log_file}" ]] || return 0

  local secret
  while IFS= read -r secret; do
    [[ -z "${secret}" ]] && continue

    # If secret is present verbatim in the log, that's a fail.
    if grep -Fq -- "${secret}" "${log_file}"; then
      return 1
    fi
  done < <( { validation__seed_secret_values; validation__seed_secrets_from_file; } )

  return 0
}

validate_required_vars() {
  # Minimal helper to ensure variables are set.
  # Args: varnames...
  local v
  for v in "$@"; do
    if [[ -z "${!v:-}" ]]; then
      return 1
    fi
  done
  return 0
}
