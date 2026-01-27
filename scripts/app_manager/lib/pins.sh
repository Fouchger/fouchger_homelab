#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/pins.sh
# Purpose : UI-driven version pin editing
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

validate_version_value() {
  local v="$1"
  [[ -n "${v}" ]] || return 1
  [[ "${v}" == "latest" ]] && return 0
  [[ "${v}" =~ ^v?[0-9]+(\.[0-9]+){1,3}$ ]] && return 0
  return 1
}
validate_pyenv_python_version_value() { [[ "$1" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]; }
validate_python_target() {
  local v="$1"
  [[ "${v}" == "system" || "${v}" == "pyenv" ]] && return 0
  [[ "${v}" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] && return 0
  return 1
}

apm_ui_edit_version_pins() {
  write_default_env_if_missing
  load_env || true

  local v=""

  ui_input "Version Pins" "Terraform version (latest or 1.2.3):" v "${TERRAFORM_VERSION:-latest}"
  [[ -z "${v}" ]] || { validate_version_value "${v}" && TERRAFORM_VERSION="${v}" || ui_msgbox "Invalid value" "Invalid Terraform version."; }

  ui_input "Version Pins" "Packer version (latest or 1.2.3):" v "${PACKER_VERSION:-latest}"
  [[ -z "${v}" ]] || { validate_version_value "${v}" && PACKER_VERSION="${v}" || ui_msgbox "Invalid value" "Invalid Packer version."; }

  ui_input "Version Pins" "Vault version (latest or 1.2.3):" v "${VAULT_VERSION:-latest}"
  [[ -z "${v}" ]] || { validate_version_value "${v}" && VAULT_VERSION="${v}" || ui_msgbox "Invalid value" "Invalid Vault version."; }

  ui_input "Version Pins" "Helm version (latest or 1.2.3):" v "${HELM_VERSION:-latest}"
  [[ -z "${v}" ]] || { validate_version_value "${v}" && HELM_VERSION="${v}" || ui_msgbox "Invalid value" "Invalid Helm version."; }

  ui_input "Version Pins" "kubectl version (latest or 1.2.3):" v "${KUBECTL_VERSION:-latest}"
  [[ -z "${v}" ]] || { validate_version_value "${v}" && KUBECTL_VERSION="${v}" || ui_msgbox "Invalid value" "Invalid kubectl version."; }

  ui_input "Version Pins" "Python target (system, pyenv, or 3.13 / 3.13.1 / 3.14 ...):" v "${PYTHON_TARGET:-system}"
  [[ -z "${v}" ]] || { validate_python_target "${v}" && PYTHON_TARGET="${v}" || ui_msgbox "Invalid value" "Invalid Python target."; }

  ui_input "Version Pins" "Pyenv Python version (numeric, e.g. 3.13.1):" v "${PYENV_PYTHON_VERSION:-3.13.1}"
  [[ -z "${v}" ]] || { validate_pyenv_python_version_value "${v}" && PYENV_PYTHON_VERSION="${v}" || ui_msgbox "Invalid value" "Invalid pyenv Python version."; }

  # Persist by re-writing env with current selection vars + new pins
  persist_current_selection_vars
  ui_msgbox "Saved" "Version pins saved."
}
