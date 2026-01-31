#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/secrets.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Secrets loading and guardrails.
# Purpose:
#   - Ensure secrets are loaded from a single, non-versioned location.
#   - Prevent accidental printing or sourcing of secrets from config/.
# Usage:
#   source "${ROOT_DIR}/lib/secrets.sh"
#   secrets_load
#   secrets_require PROXMOX_TOKEN_ID PROXMOX_TOKEN_SECRET
# Prerequisites:
#   - bash >= 4
#   - lib/env.sh initialised (STATE_DIR available) OR ROOT_DIR set
#   - lib/logger.sh loaded if you want values registered for redaction
# Notes:
#   - Authoritative file: state/secrets.env (gitignored)
#   - secrets.env.example is a template only and must not be sourced.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

secrets__file_path() {
  [[ -n "${STATE_DIR:-}" ]] || {
    [[ -n "${ROOT_DIR:-}" ]] || return 1
    STATE_DIR="${ROOT_DIR}/state"
  }
  printf '%s' "${STATE_DIR}/secrets.env"
}

secrets_load() {
  # Loads secrets from state/secrets.env into the environment.
  # Does not print values.
  local f
  f="$(secrets__file_path)"

  [[ -f "${f}" ]] || return 0

  # Basic permission check: prefer user-only readable.
  # If stat is unavailable or permissions differ, we continue but avoid noise.
  local perms
  perms="$(stat -c '%a' "${f}" 2>/dev/null || true)"
  if [[ -n "${perms}" ]] && [[ "${perms}" != "600" ]] && [[ "${perms}" != "400" ]]; then
    chmod 600 "${f}" 2>/dev/null || true
  fi

  # shellcheck disable=SC1090
  set -a
  source "${f}"
  set +a

  # Register any obvious secret-like values with the logger redaction list.
  if declare -F logger_add_redact_value >/dev/null 2>&1; then
    local k
    for k in $(compgen -e); do
      case "${k^^}" in
        *TOKEN*|*SECRET*|*PASSWORD*|*PASS*|*API_KEY*|*ACCESS_KEY*|*PRIVATE_KEY*)
          logger_add_redact_value "${!k:-}"
          ;;
      esac
    done
  fi
}

secrets_require() {
  # Ensures the given variables are set (after secrets_load).
  # Args: varnames...
  local v
  for v in "$@"; do
    if [[ -z "${!v:-}" ]]; then
      return 1
    fi
  done
  return 0
}
