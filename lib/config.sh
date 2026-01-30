#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/config.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Configuration loading helpers (env files, defaults, overrides).
# Purpose: Provide a predictable config precedence model for the homelab runtime.
# Usage:
#   source "${ROOT_DIR}/lib/config.sh"
#   config_load_defaults
#   config_load_env_file "${ROOT_DIR}/config/settings.env"
# Prerequisites:
#   - bash >= 4
# Notes:
#   - Precedence: environment variables > config files > defaults.
#   - Do not store secrets in config/*. Use state/secrets.env (gitignored).
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

config_load_defaults() {
  : "${HOMELAB_LOG_LEVEL:=INFO}"
  : "${HOMELAB_UI:=dialog}"
  : "${DRY_RUN:=false}"
}

config_load_env_file() {
  local file="${1:-}"
  [[ -n "$file" ]] || return 0
  [[ -f "$file" ]] || return 0
  # shellcheck disable=SC1090
  set -a
  source "$file"
  set +a
}

config__is_safe_env_path() {
  # Only allow sourcing of env files from config/.
  # Secrets must never be sourced from config. Secrets live in state/secrets.env
  # and are loaded explicitly via lib/secrets.sh.
  local file="$1"
  [[ -n "${ROOT_DIR:-}" ]] || return 1
  [[ "${file}" == "${ROOT_DIR}/config/"* ]] || return 1
  [[ "${file}" == *.env ]] || return 1
  case "$(basename "${file}")" in
    *secret*|*secrets*) return 1 ;;
  esac
  return 0
}

config_load_env_file_safe() {
  local file="${1:-}"
  [[ -n "${file}" ]] || return 0
  [[ -f "${file}" ]] || return 0

  if ! config__is_safe_env_path "${file}"; then
    return 0
  fi

  config_load_env_file "${file}"
}

config_load_all() {
  # Authoritative config load order:
  # 1) Defaults
  # 2) config/settings.env
  # 3) config/local.env (optional, gitignored candidate)
  # 4) Caller-provided environment variables already set
  config_load_defaults

  config_load_env_file_safe "${ROOT_DIR}/config/settings.env"
  config_load_env_file_safe "${ROOT_DIR}/config/local.env"
}
