#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/constants.sh
# Purpose : Constants, defaults, and tiny helpers
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# Expected to come from your project paths layer (lib/paths.sh)
# - APPM_DIR, ENV_BACKUP_DIR, STATE_DIR, MARKER_DIR, BIN_DIR
# If they are not set, fail fast with a readable message.
require_paths() {
  local missing=()
  for v in APPM_DIR ENV_BACKUP_DIR STATE_DIR MARKER_DIR BIN_DIR; do
    [[ -n "${!v:-}" ]] || missing+=("$v")
  done
  if ((${#missing[@]})); then
    ui_msgbox "Configuration error" "Missing required path variables:\n\n${missing[*]}\n\nEnsure lib/paths.sh is loaded before app_manager."
    return 1
  fi
}

ENV_FILE="${APPM_DIR:-/tmp}/app_install_list.env"
LOG_FILE="${APPM_DIR:-/tmp}/app-manager.log"

# Version defaults (can be overridden by env file or exported env vars)
TERRAFORM_VERSION="${TERRAFORM_VERSION:-latest}"
PACKER_VERSION="${PACKER_VERSION:-latest}"
VAULT_VERSION="${VAULT_VERSION:-latest}"
HELM_VERSION="${HELM_VERSION:-latest}"
KUBECTL_VERSION="${KUBECTL_VERSION:-latest}"

# Legacy compatibility
NODESOURCE_NODE_MAJOR="${NODESOURCE_NODE_MAJOR:-22}"

# Mongo series
MONGODB_SERIES="${MONGODB_SERIES:-8.0}"

# yq + sops
YQ_VERSION="${YQ_VERSION:-latest}"
SOPS_VERSION="${SOPS_VERSION:-latest}"

# Python target
PYTHON_TARGET="${PYTHON_TARGET:-system}"                 # system | pyenv | 3.13 | 3.13.1 | 3.14 ...
PYENV_PYTHON_VERSION="${PYENV_PYTHON_VERSION:-3.13.1}"   # used when PYTHON_TARGET=pyenv

# Small helpers
as_root() { if [[ "${EUID}" -eq 0 ]]; then "$@"; else sudo "$@"; fi; }
need_cmd_quiet() { command -v "$1" >/dev/null 2>&1; }

validate_key() {
  local key="$1"
  [[ "$key" =~ ^[A-Za-z0-9_-]+$ ]] || {
    ui_msgbox "Invalid key" "Invalid key '${key}'. Use only letters, numbers, underscore, dash."
    return 1
  }
}

key_to_var() { printf 'APP_%s' "${1^^}" | tr '-' '_' | tr '.' '_'; }

apm_init_paths() {
  require_paths || return 1
  mkdir -p "${APPM_DIR}" "${ENV_BACKUP_DIR}" "${APPM_DIR}/.backups" >/dev/null 2>&1 || true

  # Layer 1 log rotation (keep latest 5)
  logging_rotate_file "${LOG_FILE}" "${APPM_DIR}/.backups" 5
  touch "${LOG_FILE}" >/dev/null 2>&1 || true
  logging_set_layer1_file "${LOG_FILE}"
}

log_line() { info "$*"; } # compatibility shim

backup_env_file() {
  [[ -f "${ENV_FILE}" ]] || return 0
  local ts
  ts="$(date -Is | tr ':' '-')"
  cp -f -- "${ENV_FILE}" "${ENV_BACKUP_DIR}/app_install_list.env.${ts}.bak"
}
