#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/tools/audit_selected_apps_standalone.sh
# Created: 2026-01-24
# Description: Standalone audit of apps marked for install in app_install_list.env
#
# Notes:
# - Reads APP_* selections from env file, then maps keys back to APP_CATALOGUE.
# - Audits dpkg packages for apt-like strategies.
# - Audits binaries/commands for non-dpkg strategies (best-effort).
# - Designed to mirror app_manager.sh logic (do not treat key as package name).
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# Guardrail: prevent double-sourcing.
if [[ -n "${_HOMELAB_PATHS_SOURCED:-}" ]]; then
  return 0
fi
readonly _HOMELAB_PATHS_SOURCED="1"

_homelab_paths_error() { echo "Error: $*" >&2; }
_homelab_paths_warn()  { echo "Warning: $*" >&2; }

_homelab_ensure_repo_marker() {
  local root="$1"
  local marker="$2"
  local marker_path ignore_path

  marker_path="${root%/}/$marker"
  ignore_path="${root%/}/.gitignore"

  if [[ ! -f "$marker_path" ]]; then
    : >"$marker_path" 2>/dev/null || {
      _homelab_paths_warn "unable to create repo marker at $marker_path"
      return 0
    }
  fi

  # Update .gitignore in a safe, idempotent way.
  if [[ -f "$ignore_path" ]]; then
    if ! grep -qxF "$marker" "$ignore_path" 2>/dev/null; then
      printf '%s\n' "$marker" >>"$ignore_path" 2>/dev/null || _homelab_paths_warn "unable to update $ignore_path"
    fi
  else
    printf '%s\n' "$marker" >"$ignore_path" 2>/dev/null || _homelab_paths_warn "unable to create $ignore_path"
  fi
}

_find_repo_root_by_marker() {
  local dir="$PWD"
  local marker=".homelab_repo_root"

  while :; do
    if [[ -f "${dir%/}/$marker" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    [[ "$dir" == "/" ]] && break
    dir="${dir%/*}"
    [[ -z "$dir" ]] && dir="/"
  done

  return 1
}

resolve_repo_root() {
  local marker=".homelab_repo_root"
  local repo_root=""

  # 0) Honour existing REPO_ROOT only if it looks valid.
  if [[ -n "${REPO_ROOT:-}" && -d "${REPO_ROOT:-}" ]]; then
    # If marker exists, we trust it. If git exists, we can also trust .git/.gitfile layouts via git.
    if [[ -f "${REPO_ROOT%/}/$marker" ]]; then
      printf '%s' "$REPO_ROOT"
      return 0
    fi
  fi

  # 1) Preferred: ask Git (handles worktrees/submodules properly).
  if command -v git >/dev/null 2>&1; then
    if repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
      REPO_ROOT="$repo_root"
      export REPO_ROOT
      _homelab_ensure_repo_marker "$REPO_ROOT" "$marker"
      printf '%s' "$REPO_ROOT"
      return 0
    fi
  fi

  # 2) Fallback: marker walk.
  if repo_root="$(_find_repo_root_by_marker)"; then
    REPO_ROOT="$repo_root"
    export REPO_ROOT
    printf '%s' "$REPO_ROOT"
    return 0
  fi

  _homelab_paths_error "not inside a recognised repository (no git root and no $marker found)"
  return 1
}

# Resolve immediately on source, as your current file expects.
# Caller can override by exporting REPO_ROOT beforehand.
REPO_ROOT="$(resolve_repo_root)" || return 1
export REPO_ROOT
echo "Resolved REPO_ROOT: ${REPO_ROOT}"

# shellcheck source=lib/modules.sh
source "${REPO_ROOT}/lib/modules.sh"
homelab_load_lib
homelab_load_modules

# STATE_DIR="${STATE_DIR:-/root/.config/fouchger_homelab/app_manager}"
# APP_ENV_FILE="${APP_ENV_FILE:-${STATE_DIR}/app_install_list.env}"
# APPM_DIR="${STATE_DIR_DEFAULT}/app_manager"

# Point this at your repo path if running standalone.
# shellcheck disable=SC1091
source "/root/Fouchger/fouchger_homelab/scripts/core/app_manager.sh"

if [[ ! -f "${APP_ENV_FILE}" ]]; then
  echo "Error: ${APP_ENV_FILE} not found" >&2
  exit 1
fi

catalogue_row_for_key() {
  local want="$1" row type key
  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key _rest <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    [[ "${key}" == "${want}" ]] || continue
    printf '%s\n' "${row}"
    return 0
  done
  return 1
}

is_pkg_installed_local() {
  dpkg-query -W --showformat='${Status}\n' "$1" 2>/dev/null | grep -q "install ok installed"
}

# 1) Read enabled app keys from env file
selected_keys=()
while IFS='=' read -r k v; do
  [[ -z "${k}" || "${k}" =~ ^[[:space:]]*# ]] && continue
  [[ "${k}" =~ ^APP_ ]] || continue
  [[ "${v}" == "1" ]] || continue

  key="${k#APP_}"
  key="$(printf '%s' "${key}" | tr '[:upper:]' '[:lower:]')"
  selected_keys+=("${key}")
done < "${APP_ENV_FILE}"

if ((${#selected_keys[@]} == 0)); then
  echo "No applications marked for installation in ${APP_ENV_FILE}"
  exit 0
fi

fail=0

echo "Auditing enabled apps from: ${APP_ENV_FILE}"
echo

for key in "${selected_keys[@]}"; do
  row="$(catalogue_row_for_key "${key}" || true)"
  if [[ -z "${row}" ]]; then
    echo "* ${key}: WARN (key not found in catalogue)"
    continue
  fi

  IFS='|' read -r _type _key label _def pkgs_csv desc strategy _version_var <<<"${row}"
  strategy="${strategy:-apt}"

  case "${strategy}" in
    apt|hashicorp_repo|python|github_cli_repo|mongodb_repo|grafana_repo)
      if [[ -z "${pkgs_csv}" ]]; then
        echo "* ${key}: OK (no dpkg packages listed)"
        continue
      fi

      pkgs_arr=()
      pkgs_csv_to_array "${pkgs_csv}" pkgs_arr

      missing=()
      for p in "${pkgs_arr[@]}"; do
        if ! is_pkg_installed_local "${p}"; then
          missing+=("${p}")
        fi
      done

      if ((${#missing[@]} == 0)); then
        echo "* ${key}: OK (${pkgs_csv})"
      else
        echo "* ${key}: FAIL (missing: ${missing[*]})"
        fail=1
      fi
      ;;

    binary)
      # Your catalogue uses key=helm/kubectl for binary strategy
      if command -v "${key}" >/dev/null 2>&1; then
        echo "* ${key}: OK (binary present)"
      else
        echo "* ${key}: FAIL (binary missing)"
        fail=1
      fi
      ;;

    yq_binary)
      if command -v yq >/dev/null 2>&1; then
        echo "* yq: OK (binary present)"
      else
        echo "* yq: FAIL (binary missing)"
        fail=1
      fi
      ;;

    sops_binary)
      if command -v sops >/dev/null 2>&1; then
        echo "* sops: OK (binary present)"
      else
        echo "* sops: FAIL (binary missing)"
        fail=1
      fi
      ;;

    docker_script)
      if command -v docker >/dev/null 2>&1; then
        echo "* docker_cli: OK (docker present)"
      else
        echo "* docker_cli: FAIL (docker missing)"
        fail=1
      fi
      ;;

    nvm)
      # Best-effort: check for ~/.nvm of the invoking user (or SUDO_USER)
      target_user="${SUDO_USER:-$USER}"
      target_home="$(getent passwd "${target_user}" | cut -d: -f6 || true)"
      if [[ -n "${target_home}" && -d "${target_home}/.nvm" ]]; then
        echo "* nodejs: OK (nvm dir present for ${target_user})"
      else
        echo "* nodejs: FAIL (nvm dir missing for ${target_user})"
        fail=1
      fi
      ;;

    *)
      echo "* ${key}: WARN (no audit handler for strategy=${strategy})"
      ;;
  esac
done

echo
if [[ "${fail}" == "1" ]]; then
  echo "Audit result: FAIL (some enabled apps did not verify)"
  exit 1
fi

echo "Audit result: OK (all enabled apps verified)"
