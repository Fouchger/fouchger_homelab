#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/env.sh
# Purpose : Env file IO, selection operations, version var helpers
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

load_env() { [[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}" || true; }

known_version_vars() {
  printf '%s\n' \
    "TERRAFORM_VERSION" \
    "PACKER_VERSION" \
    "VAULT_VERSION" \
    "HELM_VERSION" \
    "KUBECTL_VERSION" \
    "NODESOURCE_NODE_MAJOR" \
    "MONGODB_SERIES" \
    "YQ_VERSION" \
    "SOPS_VERSION" \
    "PYTHON_TARGET" \
    "PYENV_PYTHON_VERSION"
}

default_for_version_var() {
  local var="$1"
  case "${var}" in
    PYTHON_TARGET) printf '%s' "${PYTHON_TARGET:-system}" ;;
    PYENV_PYTHON_VERSION) printf '%s' "${PYENV_PYTHON_VERSION:-3.13.1}" ;;
    NODESOURCE_NODE_MAJOR) printf '%s' "${NODESOURCE_NODE_MAJOR:-22}" ;;
    MONGODB_SERIES) printf '%s' "${MONGODB_SERIES:-8.0}" ;;
    YQ_VERSION) printf '%s' "${YQ_VERSION:-latest}" ;;
    SOPS_VERSION) printf '%s' "${SOPS_VERSION:-latest}" ;;
    *) printf '%s' "${!var:-latest}" ;;
  esac
}

get_selection_value() {
  local key="$1" var
  var="$(key_to_var "${key}")"
  printf '%s' "${!var:-0}"
}

# Writes a complete env file from:
# - version_map: either existing (load_env) or defaults
# - selection_map: built per operation
_env_write_with_maps() {
  local header="$1"
  declare -n _sel="$2"
  declare -n _ver="$3"

  backup_env_file

  {
    echo "# App install configuration"
    echo "# 1 = install, 0 = not installed"
    echo "# ${header}"
    echo "# Updated: $(date -Is)"
    echo
    echo "# Version pinning"
    local var
    while IFS= read -r var; do
      [[ -n "${var}" ]] || continue
      printf '%s=%s\n' "${var}" "${_ver[$var]}"
    done < <(known_version_vars)
    echo

    local k av
    while IFS= read -r k; do
      [[ -n "${k}" ]] || continue
      av="$(key_to_var "${k}")"
      printf '%s=%s\n' "${av}" "${_sel[$k]:-0}"
    done < <(catalogue_all_app_keys)
  } >"${ENV_FILE}"

  load_env
  log_line "ENV write: ${header}"
}

# Ensure env exists (catalogue defaults)
write_default_env_if_missing() {
  require_paths || return 1
  if [[ -f "${ENV_FILE}" ]]; then
    load_env
    return 0
  fi

  apm_init_paths
  log_line "Creating default env file: ${ENV_FILE}"

  declare -A sel=()
  declare -A ver=()

  local k
  while IFS= read -r k; do sel["$k"]=0; done < <(catalogue_all_app_keys)
  while IFS= read -r k; do sel["$k"]=1; done < <(catalogue_default_selected_keys)

  local var
  while IFS= read -r var; do ver["$var"]="$(default_for_version_var "$var")"; done < <(known_version_vars)

  _env_write_with_maps "Generated (catalogue defaults)" sel ver
}

# Behaviour 1: Apply Default (Replace)
# - replaces ALL selections with catalogue defaults
# - keeps current version pins (if env exists), otherwise defaults
apply_defaults_replace() {
  write_default_env_if_missing
  load_env || true

  declare -A sel=()
  declare -A ver=()

  local k
  while IFS= read -r k; do sel["$k"]=0; done < <(catalogue_all_app_keys)
  while IFS= read -r k; do sel["$k"]=1; done < <(catalogue_default_selected_keys)

  local var
  while IFS= read -r var; do
    ver["$var"]="${!var:-$(default_for_version_var "$var")}"
  done < <(known_version_vars)

  _env_write_with_maps "Defaults applied (replace selections)" sel ver
}

# Behaviour 2: Profile replace
# - selections become profile-only (everything else off)
# - version pins set to profile pins where provided; other vars fall back to defaults
apply_profile_replace() {
  local profile="$1"
  write_default_env_if_missing

  declare -A sel=()
  declare -A ver=()

  local k
  while IFS= read -r k; do sel["$k"]=0; done < <(catalogue_all_app_keys)
  while IFS= read -r k; do sel["$k"]=1; done < <(profile_keys_for_name "${profile}")

  local var
  while IFS= read -r var; do ver["$var"]="$(default_for_version_var "$var")"; done < <(known_version_vars)

  local line
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    ver["${line%%=*}"]="${line#*=}"
  done < <(profile_version_lines_for_name "${profile}")

  _env_write_with_maps "Profile applied (replace): ${profile}" sel ver
}

# Behaviour 2: Profile append
# - keeps existing selections and turns profile keys ON
# - only sets version vars present in the profile pins; leaves others untouched
apply_profile_append() {
  local profile="$1"
  write_default_env_if_missing
  load_env || true

  declare -A sel=()
  declare -A ver=()

  local k
  while IFS= read -r k; do sel["$k"]="$(get_selection_value "$k")"; done < <(catalogue_all_app_keys)
  while IFS= read -r k; do sel["$k"]=1; done < <(profile_keys_for_name "${profile}")

  local var
  while IFS= read -r var; do
    ver["$var"]="${!var:-$(default_for_version_var "$var")}"
  done < <(known_version_vars)

  local line
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    ver["${line%%=*}"]="${line#*=}"
  done < <(profile_version_lines_for_name "${profile}")

  _env_write_with_maps "Profile applied (append): ${profile}" sel ver
}

# Used by checklist UI to persist current shell selection vars back to env
persist_current_selection_vars() {
  write_default_env_if_missing
  load_env || true

  declare -A sel=()
  declare -A ver=()

  local k
  while IFS= read -r k; do sel["$k"]="$(get_selection_value "$k")"; done < <(catalogue_all_app_keys)

  local var
  while IFS= read -r var; do ver["$var"]="${!var:-$(default_for_version_var "$var")}"; done < <(known_version_vars)

  _env_write_with_maps "Selections updated from UI" sel ver
}
