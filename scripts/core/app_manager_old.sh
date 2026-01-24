#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/core/app_manager.sh
# Created: 2026-01-23
# Description: Ubuntu LXC App Manager (dialog UI) wired into fouchger_homelab menus.
#
# Purpose
#   Provides an interactive selection + install/uninstall manager for Ubuntu 24.04+
#   LXC containers (Proxmox-friendly). Uses the project-standard UI helpers from
#   lib/ui.sh and persists selections + version pins to an env file.
#
# How it plugs in
#   - This file is intended to be sourced by bin/homelab.
#   - Exposes a single menu entrypoint:
#       app_manager_menu
#
# Design notes
#   - UI: uses ui_menu/ui_checklist/ui_input/ui_confirm/ui_msgbox only
#   - Safe-by-default removals: only removes items this tool installed (marker-based)
#   - Prefers nala where available; falls back to apt-get
#
# Developer notes
#   - Keep this script self-contained: no direct dialog calls.
#   - Uses STATE_DIR_DEFAULT for env + backups to avoid writing inside repo.
#   - Markers remain in /usr/local/share so the “installed by app manager” state
#     is shared for the container, independent of where the repo lives.
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# =============================================================================
# Paths and constants
# =============================================================================
# see lib/paths.sh for folders

ENV_FILE="${APPM_DIR}/app_install_list.env"
LOG_FILE="${APPM_DIR}/app-manager.log"

# =============================================================================
# Version pinning defaults (can be overridden by env file or exported env vars)
# =============================================================================
TERRAFORM_VERSION="${TERRAFORM_VERSION:-latest}"
PACKER_VERSION="${PACKER_VERSION:-latest}"
VAULT_VERSION="${VAULT_VERSION:-latest}"
HELM_VERSION="${HELM_VERSION:-latest}"
KUBECTL_VERSION="${KUBECTL_VERSION:-latest}"

# NOTE: Node is installed via NVM (per-user), not NodeSource APT.
# Keep this var for compatibility if you previously persisted it, but it's not
# used by the NVM installer. Prefer NVM_NODE_VERSION for pinning instead.
NODESOURCE_NODE_MAJOR="${NODESOURCE_NODE_MAJOR:-22}"

# NEW: MongoDB major.minor line (MongoDB repo line differs by series)
MONGODB_SERIES="${MONGODB_SERIES:-8.0}"

# NEW: yq + sops pinning (optional; latest if unset)
YQ_VERSION="${YQ_VERSION:-latest}"
SOPS_VERSION="${SOPS_VERSION:-latest}"

# Default Python target: system (stable baseline).
PYTHON_TARGET="${PYTHON_TARGET:-system}"                 # system | pyenv | 3.13 | 3.13.1 | 3.14 ...
PYENV_PYTHON_VERSION="${PYENV_PYTHON_VERSION:-3.13.1}"   # used when PYTHON_TARGET=pyenv

# =============================================================================
# Application catalogue
# Format (TYPE|...):
#   HEADING|<text>
#   BLANK|<text>
#   APP|<key>|<label>|<default:ON/OFF>|<packages_csv>|<description>|<strategy>|<version_var>
# Notes
#   - packages are CSV (comma-separated), not space-separated
# =============================================================================
APP_CATALOGUE=(
  "HEADING|1. Core System and Operations Tooling"
  "APP|openssh|[Core] OpenSSH server/client|ON|openssh-server,openssh-client|Remote access|apt|"
  "APP|sudo|[Core] sudo + coreutils|ON|sudo,coreutils|Privilege escalation and base utilities|apt|"
  "APP|curl|[Core] curl|ON|curl|HTTP client|apt|"
  "APP|wget|[Core] wget|ON|wget|Downloader|apt|"
  "APP|rsync|[Core] rsync|ON|rsync|File synchronisation|apt|"
  "APP|tmux|[Core] tmux|ON|tmux|Terminal multiplexer|apt|"
  "APP|htop|[Core] htop|ON|htop|Process viewer|apt|"
  "APP|btop|[Core] btop (alternative)|OFF|btop|Modern process viewer|apt|"
  "APP|chrony|[Core] chrony|ON|chrony|Time synchronisation|apt|"
  "APP|logrotate|[Core] logrotate|ON|logrotate|Log rotation|apt|"

  "BLANK| "
  "HEADING|2. Package, Build, and Runtime Tooling"
  "APP|build_essential|[Build] build-essential|OFF|build-essential|Compiler toolchain|apt|"
  "APP|make|[Build] make|OFF|make|Build automation|apt|"
  "APP|cmake|[Build] cmake|OFF|cmake|Modern build system|apt|"
  "APP|git|[Build] git|ON|git|Source control|apt|"
  "APP|gh|[Build] gh (GitHub CLI)|ON|gh|GitHub CLI tool|github_cli_repo|"
  "APP|python|[Build] Python tooling (versioned)|OFF|python3,python3-venv,pipx|Python runtime and tooling|python|PYTHON_TARGET"

  # CORRECTION: This installer is NVM-based (per-user). Label + strategy renamed accordingly.
  # Packages remain empty because NVM installs Node without system packages.
  # Pin using NVM_NODE_VERSION (e.g. lts/*, v22.16.0) rather than NODESOURCE_NODE_MAJOR.
  "APP|nodejs|[Build] Node.js (NVM)|OFF||Node.js runtime installed via NVM (per-user)|nvm|"

  "APP|openjdk|[Build] OpenJDK 17|OFF|openjdk-17-jdk|Java runtime|apt|"
  "APP|golang|[Build] Go|OFF|golang-go|Go language toolchain|apt|"

  "BLANK| "
  "HEADING|3. Infrastructure and Automation Tools"
  "APP|ansible|[Infra] Ansible|OFF|ansible|Configuration management|apt|"
  "APP|terraform|[Infra] Terraform|OFF|terraform|Infrastructure as code|hashicorp_repo|TERRAFORM_VERSION"
  "APP|packer|[Infra] Packer|OFF|packer|Image automation|hashicorp_repo|PACKER_VERSION"
  "APP|helm|[Infra] Helm (binary)|OFF||Kubernetes package manager|binary|HELM_VERSION"
  "APP|kubectl|[Infra] kubectl (binary)|OFF||Kubernetes CLI|binary|KUBECTL_VERSION"
  "APP|jq|[Infra] jq|ON|jq|JSON processor|apt|"
  "APP|yq|[Infra] yq (mikefarah, binary)|OFF||YAML processor|yq_binary|YQ_VERSION"

  "BLANK| "
  "HEADING|4. Containers and Platform Engineering (CLI only)"
  "APP|docker_cli|[Containers] Docker Engine (get.docker.com)|OFF||Docker Engine via Docker convenience script|docker_script|"
  "APP|podman_cli|[Containers] Podman CLI|OFF|podman|Rootless container tooling|apt|"
  "APP|docker_compose|[Containers] docker-compose|OFF|docker-compose|Compose CLI|apt|"

  "BLANK| "
  "HEADING|5. Databases and Data Services"
  "APP|postgres|[Data] PostgreSQL|OFF|postgresql|Relational database|apt|"
  "APP|mysql|[Data] MySQL|OFF|mysql-server|Relational database|apt|"
  "APP|mariadb|[Data] MariaDB|OFF|mariadb-server|MySQL-compatible database|apt|"
  "APP|redis|[Data] Redis|OFF|redis-server|In-memory datastore|apt|"
  "APP|mongodb|[Data] MongoDB Community (mongodb-org)|OFF|mongodb-org|Document database via MongoDB repo|mongodb_repo|MONGODB_SERIES"

  "BLANK| "
  "HEADING|6. Observability and Diagnostics"
  "APP|nettools|[Obs] net-tools|OFF|net-tools|Legacy networking tools|apt|"
  "APP|iproute2|[Obs] iproute2|ON|iproute2|Modern networking tools|apt|"
  "APP|tcpdump|[Obs] tcpdump|OFF|tcpdump|Packet capture|apt|"
  "APP|strace|[Obs] strace|OFF|strace|Syscall tracing|apt|"
  "APP|grafana_alloy|[Obs] Grafana Alloy|OFF|alloy|OpenTelemetry collector distro (Grafana)|grafana_repo|"

  "BLANK| "
  "HEADING|7. Security and Access Tooling"
  "APP|gpg|[Sec] GnuPG|ON|gnupg|Encryption and signing|apt|"
  "APP|pass|[Sec] pass|OFF|pass|Password store|apt|"
  "APP|vault|[Sec] Vault CLI|OFF|vault|Secrets management|hashicorp_repo|VAULT_VERSION"
  "APP|age|[Sec] age|OFF|age|Modern encryption|apt|"
  "APP|sops|[Sec] sops (binary)|OFF||Secrets operations|sops_binary|SOPS_VERSION"
)

# =============================================================================
# Profiles (apps)
# =============================================================================
PROFILE_BASIC_KEYS=(openssh sudo curl wget rsync tmux htop btop chrony logrotate jq iproute2 gpg git gh)
PROFILE_DEV_KEYS=( "${PROFILE_BASIC_KEYS[@]}" build_essential make cmake python nodejs openjdk golang )
PROFILE_AUTOMATION_KEYS=( "${PROFILE_BASIC_KEYS[@]}" ansible terraform packer yq )
PROFILE_PLATFORM_KEYS=( "${PROFILE_AUTOMATION_KEYS[@]}" helm kubectl docker_cli podman_cli docker_compose tcpdump strace )
PROFILE_DATABASE_KEYS=( "${PROFILE_BASIC_KEYS[@]}" postgres mysql mariadb redis mongodb )
PROFILE_OBSERVABILITY_KEYS=( "${PROFILE_BASIC_KEYS[@]}" nettools grafana_alloy )
PROFILE_SECURITY_KEYS=( "${PROFILE_BASIC_KEYS[@]}" pass vault age sops )

profile_all_keys_unique() {
  printf '%s\n' \
    "${PROFILE_BASIC_KEYS[@]}" \
    "${PROFILE_DEV_KEYS[@]}" \
    "${PROFILE_AUTOMATION_KEYS[@]}" \
    "${PROFILE_PLATFORM_KEYS[@]}" \
    "${PROFILE_DATABASE_KEYS[@]}" \
    "${PROFILE_OBSERVABILITY_KEYS[@]}" \
    "${PROFILE_SECURITY_KEYS[@]}" \
  | awk 'NF' | sort -u
}
mapfile -t PROFILE_ALL_KEYS < <(profile_all_keys_unique)

# =============================================================================
# Profiles (version pinning)
# =============================================================================
PROFILE_BASIC_VERSION_LINES=()
PROFILE_DEV_VERSION_LINES=( "PYTHON_TARGET=system" "PYENV_PYTHON_VERSION=3.13.1" )
PROFILE_AUTOMATION_VERSION_LINES=( "TERRAFORM_VERSION=latest" "PACKER_VERSION=latest" "VAULT_VERSION=latest" )
PROFILE_PLATFORM_VERSION_LINES=(
  "TERRAFORM_VERSION=latest"
  "PACKER_VERSION=latest"
  "VAULT_VERSION=latest"
  "HELM_VERSION=latest"
  "KUBECTL_VERSION=latest"
  "PYTHON_TARGET=system"
  "PYENV_PYTHON_VERSION=3.13.1"
)
PROFILE_DATABASE_VERSION_LINES=()
PROFILE_OBSERVABILITY_VERSION_LINES=()
PROFILE_SECURITY_VERSION_LINES=( "VAULT_VERSION=latest" )
PROFILE_ALL_VERSION_LINES=( "${PROFILE_PLATFORM_VERSION_LINES[@]}" "${PROFILE_SECURITY_VERSION_LINES[@]}" )

# =============================================================================
# Small helpers
# =============================================================================
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
  mkdir -p "${APPM_DIR}" "${ENV_BACKUP_DIR}" >/dev/null 2>&1 || true
  touch "${LOG_FILE}" >/dev/null 2>&1 || true
}

log_line() {
  local msg
  msg="$(date -Is) $*"
  printf '%s\n' "${msg}" >>"${LOG_FILE}" 2>/dev/null || true
}

backup_env_file() {
  [[ -f "${ENV_FILE}" ]] || return 0
  local ts
  ts="$(date -Is | tr ':' '-')"
  cp -f -- "${ENV_FILE}" "${ENV_BACKUP_DIR}/app_install_list.env.${ts}.bak"
}

load_env() { [[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}" || true; }

get_selection_value() {
  local key="$1" var
  var="$(key_to_var "${key}")"
  printf '%s' "${!var:-0}"
}

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


profile_version_lines_for_name() {
  local name="$1"
  case "${name}" in
    basic)         printf '%s\n' "${PROFILE_BASIC_VERSION_LINES[@]}" ;;
    dev)           printf '%s\n' "${PROFILE_DEV_VERSION_LINES[@]}" ;;
    automation)    printf '%s\n' "${PROFILE_AUTOMATION_VERSION_LINES[@]}" ;;
    platform)      printf '%s\n' "${PROFILE_PLATFORM_VERSION_LINES[@]}" ;;
    database)      printf '%s\n' "${PROFILE_DATABASE_VERSION_LINES[@]}" ;;
    observability) printf '%s\n' "${PROFILE_OBSERVABILITY_VERSION_LINES[@]}" ;;
    security)      printf '%s\n' "${PROFILE_SECURITY_VERSION_LINES[@]}" ;;
    all)           printf '%s\n' "${PROFILE_ALL_VERSION_LINES[@]}" ;;
    *) return 1 ;;
  esac
}

profile_keys_for_name() {
  local name="$1"
  case "${name}" in
    basic)         printf '%s\n' "${PROFILE_BASIC_KEYS[@]}" ;;
    dev)           printf '%s\n' "${PROFILE_DEV_KEYS[@]}" ;;
    automation)    printf '%s\n' "${PROFILE_AUTOMATION_KEYS[@]}" ;;
    platform)      printf '%s\n' "${PROFILE_PLATFORM_KEYS[@]}" ;;
    database)      printf '%s\n' "${PROFILE_DATABASE_KEYS[@]}" ;;
    observability) printf '%s\n' "${PROFILE_OBSERVABILITY_KEYS[@]}" ;;
    security)      printf '%s\n' "${PROFILE_SECURITY_KEYS[@]}" ;;
    all)           printf '%s\n' "${PROFILE_ALL_KEYS[@]}" ;;
    *) return 1 ;;
  esac
}

all_app_keys() {
  local row type key label def pkgs_csv desc strategy version_var
  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    validate_key "${key}" || continue
    printf '%s\n' "${key}"
  done
}

write_env_file() {
  local header="$1"
  local mode="$2"
  local profile="${3:-}"

  local -A sel_on=()
  local -A ver_override=()
  local k line var val

  if [[ "${mode}" == "replace" || "${mode}" == "add" ]]; then
    while IFS= read -r k; do
      [[ -n "${k}" ]] || continue
      sel_on["$k"]=1
    done < <(profile_keys_for_name "${profile}")

    while IFS= read -r line; do
      [[ -n "${line}" ]] || continue
      var="${line%%=*}"
      val="${line#*=}"
      ver_override["$var"]="$val"
    done < <(profile_version_lines_for_name "${profile}")
  fi

  backup_env_file

  {
    echo "# App install configuration"
    echo "# 1 = install, 0 = not installed"
    echo "# ${header}"
    echo "# Updated: $(date -Is)"
    echo
    echo "# Version pinning"
    while IFS= read -r var; do
      [[ -n "${var}" ]] || continue
      if [[ "${mode}" == "replace" || "${mode}" == "add" ]]; then
        if [[ -n "${ver_override[$var]:-}" ]]; then
          printf '%s=%s\n' "${var}" "${ver_override[$var]}"
        else
          printf '%s=%s\n' "${var}" "$(default_for_version_var "${var}")"
        fi
      else
        printf '%s=%s\n' "${var}" "$(default_for_version_var "${var}")"
      fi
    done < <(known_version_vars)
    echo

    while IFS= read -r k; do
      local av cur
      av="$(key_to_var "${k}")"
      case "${mode}" in
        replace)
          if [[ -n "${sel_on[$k]:-}" ]]; then echo "${av}=1"; else echo "${av}=0"; fi
          ;;
        add)
          cur="$(get_selection_value "${k}")"
          if [[ -n "${sel_on[$k]:-}" ]]; then echo "${av}=1"; else echo "${av}=${cur:-0}"; fi
          ;;
        from_ui)
          cur="$(get_selection_value "${k}")"
          echo "${av}=${cur:-0}"
          ;;
        *) echo "${av}=0" ;;
      esac
    done < <(all_app_keys)
  } >"${ENV_FILE}"

  load_env
  log_line "ENV write: ${header} (mode=${mode} profile=${profile})"
}

write_default_env_if_missing() {
  if [[ -f "${ENV_FILE}" ]]; then
    load_env
    return 0
  fi

  apm_init_paths
  log_line "Creating default env file: ${ENV_FILE}"

  {
    echo "# App install configuration"
    echo "# 1 = install, 0 = not installed"
    echo "# Generated: $(date -Is)"
    echo
    echo "# Version pinning"
    echo "TERRAFORM_VERSION=${TERRAFORM_VERSION}"
    echo "PACKER_VERSION=${PACKER_VERSION}"
    echo "VAULT_VERSION=${VAULT_VERSION}"
    echo "HELM_VERSION=${HELM_VERSION}"
    echo "KUBECTL_VERSION=${KUBECTL_VERSION}"
    echo "PYTHON_TARGET=${PYTHON_TARGET}"
    echo "PYENV_PYTHON_VERSION=${PYENV_PYTHON_VERSION}"
    echo "NODESOURCE_NODE_MAJOR=${NODESOURCE_NODE_MAJOR}"
    echo "MONGODB_SERIES=${MONGODB_SERIES}"
    echo "YQ_VERSION=${YQ_VERSION}"
    echo "SOPS_VERSION=${SOPS_VERSION}"
    echo
    local row type key label def pkgs_csv desc strategy version_var v
    for row in "${APP_CATALOGUE[@]}"; do
      IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
      [[ "${type}" == "APP" ]] || continue
      validate_key "${key}" || continue
      v="$(key_to_var "${key}")"
      if [[ "${def}" == "ON" ]]; then echo "${v}=1"; else echo "${v}=0"; fi
    done
  } >"${ENV_FILE}"

  load_env
}

# =============================================================================
# Apt package availability checks (prevents a single missing package killing the run)
# =============================================================================
apt_pkg_has_candidate() {
  local pkg="$1"
  apt-cache policy "${pkg}" 2>/dev/null | awk -F': ' '
    $1=="Candidate" { cand=$2 }
    END {
      if (cand=="" || cand=="(none)") exit 1
      exit 0
    }
  '
}


filter_installable_apt_pkgs() {
  local in_name="$1" out_name="$2" missing_name="$3"
  local -a installable=() missing=()
  local p

  eval "for p in \"\${${in_name}[@]}\"; do
    if apt_pkg_has_candidate \"\$p\"; then
      installable+=(\"\$p\")
    else
      missing+=(\"\$p\")
    fi
  done"

  eval "${out_name}=(\"\${installable[@]}\")"
  eval "${missing_name}=(\"\${missing[@]}\")"
}


# =============================================================================
# CSV helpers
# =============================================================================
pkgs_csv_to_array() {
  local csv="$1" out_name="$2"
  eval "${out_name}=()"
  [[ -n "${csv}" ]] || return 0

  local -a tmp=()
  local IFS=','

  # shellcheck disable=SC2206
  tmp=(${csv})

  local -a cleaned=()
  local x
  for x in "${tmp[@]}"; do
    x="${x#"${x%%[![:space:]]*}"}"
    x="${x%"${x##*[![:space:]]}"}"
    [[ -n "${x}" ]] && cleaned+=("${x}")
  done

  eval "${out_name}=(\"\${cleaned[@]}\")"
}

unique_pkgs() {
  local in_name="$1" out_name="$2"
  local -a out=()

  # Expand the full input array via eval, one item per line, then sort unique.
  mapfile -t out < <(
    eval "printf '%s\n' \"\${${in_name}[@]}\"" \
      | awk 'NF' \
      | sort -u
  )

  eval "${out_name}=(\"\${out[@]}\")"
}

is_pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

verify_pkgs_installed() {
  local pkgs_csv="$1"
  local -a pkgs_arr=()
  pkgs_csv_to_array "${pkgs_csv}" pkgs_arr
  local p
  for p in "${pkgs_arr[@]}"; do
    is_pkg_installed "${p}" || return 1
  done
  return 0
}

# =============================================================================
# Version validation
# =============================================================================
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

# =============================================================================
# Marker tracking (conservative removals)
# =============================================================================
ensure_state_dirs() { as_root mkdir -p "${STATE_DIR}" "${MARKER_DIR}"; }
marker_path() { printf '%s/%s.installed_by_app_manager' "${MARKER_DIR}" "$1"; }
is_marked_installed() { [[ -f "$(marker_path "$1")" ]]; }
unmark_installed() { as_root rm -f -- "$(marker_path "$1")" >/dev/null 2>&1 || true; }

mark_installed() {
  local key="$1" strategy="${2:-}" packages_csv="${3:-}"
  ensure_state_dirs
  as_root bash -c "cat > \"$(marker_path "${key}")\" << EOF
installed_at=$(date -Is)
strategy=${strategy}
packages_csv=${packages_csv}
EOF"
}

marker_get_field() {
  local key="$1" field="$2"
  [[ -f "$(marker_path "${key}")" ]] || return 1
  awk -F= -v f="${field}" '$1==f {sub(/^[^=]+=/,""); print; exit}' "$(marker_path "${key}")"
}

marker_get_packages_compat_csv() {
  local key="$1" v
  v="$(marker_get_field "${key}" "packages_csv" 2>/dev/null || true)"
  if [[ -n "${v}" ]]; then
    printf '%s\n' "${v}"
    return 0
  fi
  v="$(marker_get_field "${key}" "packages" 2>/dev/null || true)"
  printf '%s\n' "${v}" | tr ' ' ',' | tr -s ','
}

# =============================================================================
# Package manager (prefer nala)
# =============================================================================
PKG_MGR="apt-get"

detect_pkg_mgr() { if need_cmd_quiet nala; then PKG_MGR="nala"; else PKG_MGR="apt-get"; fi; }

ensure_pkg_mgr() {
  detect_pkg_mgr
  if [[ "${PKG_MGR}" == "nala" ]]; then return 0; fi

  log_line "nala not found; bootstrapping via apt-get"
  as_root apt-get update
  as_root apt-get install -y --no-install-recommends nala || true

  detect_pkg_mgr
}

pkg_update_once() {
  if [[ "${PKG_MGR}" == "nala" ]]; then as_root nala update
  else as_root apt-get update
  fi
}

pkg_install_pkgs() {
  (("$#")) || return 0
  if [[ "${PKG_MGR}" == "nala" ]]; then as_root nala install -y --no-install-recommends "$@"
  else as_root apt-get install -y --no-install-recommends "$@"
  fi
}

pkg_remove_pkgs() {
  (("$#")) || return 0
  if [[ "${PKG_MGR}" == "nala" ]]; then as_root nala remove -y "$@" >/dev/null 2>&1 || true
  else as_root apt-get remove -y "$@" >/dev/null 2>&1 || true
  fi
}

pkg_autoremove() {
  if [[ "${PKG_MGR}" == "nala" ]]; then as_root nala autoremove -y
  else as_root apt-get autoremove -y
  fi
}

ensure_nodesource_repo() {
  # =============================================================================
  # Install Node.js via NVM (Node Version Manager) for the invoking user.
  #
  # Why:
  #   - More flexible than apt repos: multiple Node versions per user, easy upgrades.
  #   - Matches the recommended NVM install approach (download install.sh, then run).
  #
  # Behaviour:
  #   - Installs nvm under the target user's home (~/.nvm)
  #   - Installs a Node version (default: lts/*) and sets it as default alias
  #
  # Controls (env vars):
  #   - NVM_VERSION:        nvm version tag (default: latest release tag, e.g. v0.40.3)
  #   - NVM_NODE_VERSION:   Node version or alias (default: lts/*, examples: v22.16.0, lts/jod)
  #   - NVM_AUDIT_ONLY=1:   Downloads install script and stops (lets you review before running)
  # =============================================================================

  pkg_update_once
  pkg_install_pkgs ca-certificates curl bash

  local nvm_version="${NVM_VERSION:-latest}"
  local node_version="${NVM_NODE_VERSION:-lts/*}"

  # Resolve "latest" to the latest release tag (e.g. v0.40.3)
  if [[ "${nvm_version}" == "latest" ]]; then
    # github_latest_tag strips leading 'v', so we add it back for the URL.
    local resolved
    resolved="$(github_latest_tag "nvm-sh/nvm" 2>/dev/null || true)"
    [[ -n "${resolved}" ]] || { ui_msgbox "Error" "Could not resolve latest nvm version from GitHub."; return 1; }
    nvm_version="v${resolved}"
  fi

  # Decide who gets NVM installed (per-user install)
  local target_user target_home
  target_user="${SUDO_USER:-$USER}"
  target_home="$(getent passwd "${target_user}" | cut -d: -f6)"
  [[ -n "${target_home}" && -d "${target_home}" ]] || { ui_msgbox "Error" "Could not determine home directory for user '${target_user}'."; return 1; }

  local td script_url script
  td="$(tmpdir_create)"
  script="${td}/nvm-install.sh"
  script_url="https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh"

  info "Preparing NVM install script: ${script_url}"
  curl -fsSL "${script_url}" -o "${script}"

  if [[ "${NVM_AUDIT_ONLY:-0}" == "1" ]]; then
    ui_msgbox "NVM audit-only" "Downloaded NVM install script to:\n\n${script}\n\nReview it, then re-run with NVM_AUDIT_ONLY=0 to install."
    return 0
  fi

  # Run installer as the target user (writes to ~/.nvm and updates shell profile)
  info "Installing NVM for user '${target_user}' (${nvm_version})"
  sudo -u "${target_user}" bash "${script}"

  # Install and set the default Node version (also as the target user)
  info "Installing Node via NVM (${node_version}) and setting default alias"
  sudo -u "${target_user}" bash -lc "
    set -euo pipefail

    export NVM_DIR=\"\$HOME/.nvm\"
    if [[ -s \"\$NVM_DIR/nvm.sh\" ]]; then
      . \"\$NVM_DIR/nvm.sh\"
    else
      echo \"Error: nvm.sh not found after install\" >&2
      exit 1
    fi

    nvm install \"${node_version}\"
    nvm alias default \"${node_version}\"

    node -v
    npm -v
  "

  rm -rf -- "${td}"
}

uninstall_nvm_node() {
  # =============================================================================
  # Uninstall NVM + Node versions installed by NVM for the target user.
  #
  # Notes:
  #   - This removes ~/.nvm and attempts to remove NVM init lines from ~/.bashrc.
  #   - It does not remove system-installed nodejs packages.
  # =============================================================================
  local target_user target_home
  target_user="${SUDO_USER:-$USER}"
  target_home="$(getent passwd "${target_user}" | cut -d: -f6)"
  [[ -n "${target_home}" && -d "${target_home}" ]] || return 0

  sudo -u "${target_user}" bash -lc '
    set -euo pipefail
    rm -rf "$HOME/.nvm" || true
    touch "$HOME/.bashrc" || true
    # Remove common NVM install snippet lines (best-effort)
    sed -i "/NVM_DIR=.*\.nvm/d" "$HOME/.bashrc" || true
    sed -i "/nvm\.sh/d" "$HOME/.bashrc" || true
    sed -i "/bash_completion.*nvm/d" "$HOME/.bashrc" || true
  ' || true

  if is_marked_installed "nodejs"; then
    unmark_installed "nodejs"
  fi
}

# =============================================================================
# Vendor repo helpers (NEW)
# =============================================================================

ensure_apt_keyrings_dir() { as_root mkdir -p /etc/apt/keyrings; }

# GitHub CLI APT repo (packages at cli.github.com)
ensure_github_cli_repo() {
  pkg_update_once
  pkg_install_pkgs ca-certificates curl gpg

  ensure_apt_keyrings_dir
  local keyring="/etc/apt/keyrings/githubcli-archive-keyring.gpg"
  if [[ ! -f "${keyring}" ]]; then
    as_root curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "${keyring}"
    as_root chmod 0644 "${keyring}"
  fi

  local list="/etc/apt/sources.list.d/github-cli.list"
  local line="deb [arch=$(dpkg --print-architecture) signed-by=${keyring}] https://cli.github.com/packages stable main"
  if [[ ! -f "${list}" ]] || ! grep -Fq "${line}" "${list}"; then
    printf '%s\n' "${line}" | as_root tee "${list}" >/dev/null
  fi
}

ensure_mongodb_repo() {
  # =============================================================================
  # MongoDB official repo (mongodb-org) for Ubuntu 24.04+ (noble by default)
  #
  # Based on:
  #   curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
  #   echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
  #
  # Notes:
  #   - MongoDB warns that Ubuntu’s 'mongodb' package conflicts with mongodb-org.
  # =============================================================================

  local series="${MONGODB_SERIES:-8.0}"
  local codename
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
  [[ -n "${codename}" ]] || { ui_msgbox "Error" "Could not determine OS codename for MongoDB repo setup."; return 1; }

  if ! need_cmd_quiet curl || ! need_cmd_quiet gpg; then
    pkg_update_once
    pkg_install_pkgs ca-certificates curl gpg
  fi

  local keyring="/usr/share/keyrings/mongodb-server-${series}.gpg"
  local list="/etc/apt/sources.list.d/mongodb-org-${series}.list"

  if [[ ! -f "${keyring}" ]]; then
    as_root bash -c "curl -fsSL https://www.mongodb.org/static/pgp/server-${series}.asc | gpg --dearmor -o '${keyring}'"
    as_root chmod 0644 "${keyring}"
  fi

  local line="deb [ arch=amd64,arm64 signed-by=${keyring} ] https://repo.mongodb.org/apt/ubuntu ${codename}/mongodb-org/${series} multiverse"
  if [[ ! -f "${list}" ]] || ! grep -Fq "${line}" "${list}"; then
    printf '%s\n' "${line}" | as_root tee "${list}" >/dev/null
  fi
}

ensure_grafana_repo() {
  # =============================================================================
  # Grafana APT repo for Alloy (Debian/Ubuntu)
  #
  # Based on Grafana Alloy docs:
  #   sudo mkdir -p /etc/apt/keyrings
  #   sudo wget -O /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key
  #   sudo chmod 644 /etc/apt/keyrings/grafana.asc
  #   echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
  #
  # Notes:
  #   - Some Debian-based images may not have gpg; the referenced docs mention installing it.
  #     This repo method uses a raw ASCII key file, but we still ensure gpg is present to
  #     support other repo patterns and consistency.
  # =============================================================================

  pkg_update_once
  pkg_install_pkgs ca-certificates wget gpg || true

  local keyrings_dir="/etc/apt/keyrings"
  local keyfile="${keyrings_dir}/grafana.asc"
  local list="/etc/apt/sources.list.d/grafana.list"
  local line="deb [signed-by=${keyfile}] https://apt.grafana.com stable main"

  as_root mkdir -p "${keyrings_dir}"

  if [[ ! -f "${keyfile}" ]]; then
    as_root wget -qO "${keyfile}" https://apt.grafana.com/gpg-full.key
    as_root chmod 0644 "${keyfile}"
  else
    # Keep permissions correct if file already exists
    as_root chmod 0644 "${keyfile}" || true
  fi

  if [[ ! -f "${list}" ]] || ! grep -Fq "${line}" "${list}"; then
    printf '%s\n' "${line}" | as_root tee "${list}" >/dev/null
  fi
}

uninstall_grafana_alloy() {
  # =============================================================================
  # Uninstall Grafana Alloy (Debian/Ubuntu) + optional repo cleanup
  #
  # Based on Grafana Alloy docs:
  #   sudo systemctl stop alloy
  #   sudo apt-get remove alloy
  #   optional: sudo rm -i /etc/apt/sources.list.d/grafana.list
  #
  # Controls (env vars):
  #   - REMOVE_GRAFANA_REPO=1    Remove /etc/apt/sources.list.d/grafana.list
  #   - REMOVE_GRAFANA_KEY=1     Remove /etc/apt/keyrings/grafana.asc
  # =============================================================================

  # Stop service if systemd is present (best-effort)
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    as_root systemctl stop alloy >/dev/null 2>&1 || true
    as_root systemctl disable alloy >/dev/null 2>&1 || true
  fi

  # Remove package
  pkg_update_once
  pkg_remove_pkgs alloy || true
  pkg_autoremove || true

  # Optional: remove repo + key (non-destructive by default)
  if [[ "${REMOVE_GRAFANA_REPO:-0}" == "1" ]]; then
    as_root rm -f /etc/apt/sources.list.d/grafana.list || true
  fi
  if [[ "${REMOVE_GRAFANA_KEY:-0}" == "1" ]]; then
    as_root rm -f /etc/apt/keyrings/grafana.asc || true
  fi

  # Refresh apt metadata if we changed sources
  if [[ "${REMOVE_GRAFANA_REPO:-0}" == "1" || "${REMOVE_GRAFANA_KEY:-0}" == "1" ]]; then
    pkg_update_once || true
  fi
}

install_sops_binary() {
  # =============================================================================
  # Install sops from GitHub release artifacts (getsops/sops)
  #
  # Based on the release instructions:
  #   curl -LO .../sops-vX.Y.Z.linux.amd64
  #   mv ... /usr/local/bin/sops
  #   chmod +x ...
  #
  # Controls (env vars):
  #   - SOPS_VERSION: latest | 3.11.0 | v3.11.0
  #   - SOPS_VERIFY:  0|1  (default: 1) verify binary integrity via checksums + sha256sum
  #   - SOPS_COSIGN_VERIFY: 0|1 (default: 0) verify checksums file signature with cosign
  #
  # Notes:
  #   - Installs to ${BIN_DIR}/sops (project standard).
  #   - Verification is best-effort; fails hard when SOPS_VERIFY=1 and checks fail.
  # =============================================================================

  local version="${SOPS_VERSION:-latest}"
  version="${version#v}"

  if [[ "${version}" == "latest" ]]; then
    local resolved
    resolved="$(github_latest_tag "getsops/sops" 2>/dev/null || true)"
    [[ -n "${resolved}" ]] || { ui_msgbox "Error" "Could not resolve latest sops version."; return 1; }
    version="${resolved}"
  fi

  local os="linux"
  local arch
  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) ui_msgbox "Error" "Unsupported architecture for sops: $(uname -m)"; return 1 ;;
  esac

  ensure_state_dirs

  # Ensure downloader exists
  if ! need_cmd_quiet curl; then
    pkg_update_once
    pkg_install_pkgs ca-certificates curl
  fi

  local td asset url bin
  td="$(tmpdir_create)"
  asset="sops-v${version}.${os}.${arch}"
  url="https://github.com/getsops/sops/releases/download/v${version}/${asset}"
  bin="${td}/${asset}"

  info "Downloading sops v${version} (${os}/${arch})"
  curl -fsSL -o "${bin}" "${url}"
  [[ -s "${bin}" ]] || { ui_msgbox "Error" "Downloaded sops binary is empty. URL: ${url}"; rm -rf -- "${td}"; return 1; }

  # Optional: verify checksums (recommended)
  local verify="${SOPS_VERIFY:-1}"
  if [[ "${verify}" == "1" ]]; then
    need_cmd_quiet sha256sum || {
      pkg_update_once
      pkg_install_pkgs coreutils
    }

    local checksums_url checksums_file
    checksums_url="https://github.com/getsops/sops/releases/download/v${version}/sops-v${version}.checksums.txt"
    checksums_file="${td}/sops-v${version}.checksums.txt"

    info "Downloading checksums file"
    curl -fsSL -o "${checksums_file}" "${checksums_url}"
    [[ -s "${checksums_file}" ]] || { ui_msgbox "Error" "Checksums file is empty. URL: ${checksums_url}"; rm -rf -- "${td}"; return 1; }

    # Optional: verify checksums file signature with cosign (off by default)
    if [[ "${SOPS_COSIGN_VERIFY:-0}" == "1" ]]; then
      need_cmd_quiet cosign || { ui_msgbox "Error" "cosign is required for signature verification. Install cosign or set SOPS_COSIGN_VERIFY=0."; rm -rf -- "${td}"; return 1; }

      local pem_url sig_url pem_file sig_file
      pem_url="https://github.com/getsops/sops/releases/download/v${version}/sops-v${version}.checksums.pem"
      sig_url="https://github.com/getsops/sops/releases/download/v${version}/sops-v${version}.checksums.sig"
      pem_file="${td}/sops-v${version}.checksums.pem"
      sig_file="${td}/sops-v${version}.checksums.sig"

      info "Downloading cosign certificate + signature for checksums"
      curl -fsSL -o "${pem_file}" "${pem_url}"
      curl -fsSL -o "${sig_file}" "${sig_url}"

      info "Verifying checksums signature with cosign"
      cosign verify-blob "${checksums_file}" \
        --certificate "${pem_file}" \
        --signature "${sig_file}" \
        --certificate-identity-regexp="https://github.com/getsops" \
        --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
        >/dev/null
    fi

    # Verify binary integrity using checksums file (ignore missing for other platforms)
    info "Verifying sops binary integrity via sha256sum"
    (
      cd "${td}"
      sha256sum -c "$(basename "${checksums_file}")" --ignore-missing
    )
  fi

  info "Installing sops to ${BIN_DIR}/sops"
  as_root install -m 0755 "${bin}" "${BIN_DIR}/sops"

  # Verify install
  if command -v sops >/dev/null 2>&1; then
    sops --version >/dev/null 2>&1 || true
  fi

  rm -rf -- "${td}"
}

uninstall_sops_binary() {
  # =============================================================================
  # Uninstall sops (binary install)
  #
  # Behaviour:
  #   - Removes ${BIN_DIR}/sops if present
  #   - Unmarks app-manager marker if it exists
  # =============================================================================

  # Remove binary (best-effort)
  as_root rm -f -- "${BIN_DIR}/sops" >/dev/null 2>&1 || true

  # Align with your marker approach
  if is_marked_installed "sops"; then
    unmark_installed "sops"
  fi
}

# =============================================================================
# HashiCorp repo (apt.releases.hashicorp.com)
# =============================================================================
ensure_hashicorp_repo() {
  if ! need_cmd_quiet curl || ! need_cmd_quiet gpg; then
    pkg_update_once
    pkg_install_pkgs ca-certificates curl gnupg
  fi

  local keyring="/usr/share/keyrings/hashicorp-archive-keyring.gpg"
  if [[ ! -f "${keyring}" ]]; then
    as_root bash -c "curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o '${keyring}'"
  fi

  local codename
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
  [[ -n "${codename}" ]] || { ui_msgbox "Error" "Could not determine OS codename for HashiCorp repo setup."; return 1; }

  local list="/etc/apt/sources.list.d/hashicorp.list"
  local line="deb [signed-by=${keyring}] https://apt.releases.hashicorp.com ${codename} main"
  if [[ ! -f "${list}" ]] || ! grep -Fq "${line}" "${list}"; then
    printf '%s\n' "${line}" | as_root tee "${list}" >/dev/null
  fi
}

# =============================================================================
# Binary installers (Helm, kubectl)
# =============================================================================
tmpdir_create() { mktemp -d; }

sha256_check() {
  local file="$1" expected="$2"
  need_cmd_quiet sha256sum || { ui_msgbox "Error" "sha256sum is required for checksum verification."; return 1; }
  [[ -n "${expected}" ]] || { ui_msgbox "Error" "Checksum expected but not provided."; return 1; }
  local actual
  actual="$(sha256sum "${file}" | awk '{print $1}')"
  [[ "${actual}" == "${expected}" ]] || { ui_msgbox "Error" "Checksum mismatch for ${file}"; return 1; }
}

github_latest_tag() {
  local repo="$1"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | awk -F'"' '/"tag_name":/ {print $4; exit}' \
    | sed 's/^v//'
}

install_helm_binary() {
  local version="${HELM_VERSION:-latest}"
  version="${version#v}"
  if [[ "${version}" == "latest" ]]; then
    version="$(github_latest_tag "helm/helm")"
    [[ -n "${version}" ]] || { ui_msgbox "Error" "Could not resolve latest Helm version."; return 1; }
  fi

  local arch os
  os="linux"
  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) ui_msgbox "Error" "Unsupported architecture for Helm: $(uname -m)"; return 1 ;;
  esac

  local td tgz url sums_url sum
  td="$(tmpdir_create)"
  tgz="${td}/helm.tgz"
  url="https://get.helm.sh/helm-v${version}-${os}-${arch}.tar.gz"
  sums_url="https://get.helm.sh/helm-v${version}-${os}-${arch}.tar.gz.sha256sum"

  curl -fsSL -o "${tgz}" "${url}"
  sum="$(curl -fsSL "${sums_url}" | awk '{print $1}')"
  sha256_check "${tgz}" "${sum}"

  tar -xzf "${tgz}" -C "${td}"
  as_root install -m 0755 "${td}/${os}-${arch}/helm" "${BIN_DIR}/helm"
  rm -rf -- "${td}"
}

remove_helm_binary() {
  if is_marked_installed "helm"; then
    as_root rm -f -- "${BIN_DIR}/helm" >/dev/null 2>&1 || true
    unmark_installed "helm"
  fi
}

install_kubectl_binary() {
  local version="${KUBECTL_VERSION:-latest}"
  version="${version#v}"
  if [[ "${version}" == "latest" ]]; then
    version="$(curl -fsSL https://dl.k8s.io/release/stable.txt | sed 's/^v//')"
    [[ -n "${version}" ]] || { ui_msgbox "Error" "Could not resolve latest kubectl version."; return 1; }
  fi

  local arch os
  os="linux"
  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) ui_msgbox "Error" "Unsupported architecture for kubectl: $(uname -m)"; return 1 ;;
  esac

  local td bin url sum_url sum
  td="$(tmpdir_create)"
  bin="${td}/kubectl"
  url="https://dl.k8s.io/release/v${version}/bin/${os}/${arch}/kubectl"
  sum_url="https://dl.k8s.io/release/v${version}/bin/${os}/${arch}/kubectl.sha256"

  curl -fsSL -o "${bin}" "${url}"
  sum="$(curl -fsSL "${sum_url}" | tr -d '[:space:]')"
  sha256_check "${bin}" "${sum}"

  as_root install -m 0755 "${bin}" "${BIN_DIR}/kubectl"
  rm -rf -- "${td}"
}

remove_kubectl_binary() {
  if is_marked_installed "kubectl"; then
    as_root rm -f -- "${BIN_DIR}/kubectl" >/dev/null 2>&1 || true
    unmark_installed "kubectl"
  fi
}

install_yq_binary() {
  # =============================================================================
  # Install yq (mikefarah/yq) via official GitHub pre-compiled binary download.
  #
  # Source approach:
  #   - Latest:  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  #   - Pinned:  https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_${PLATFORM}
  #
  # Notes:
  #   - Uses wget if available, otherwise falls back to curl.
  #   - Installs to ${BIN_DIR}/yq (project standard) and ensures +x.
  #   - Verifies install by running "yq --version".
  #
  # Controls (env vars):
  #   - YQ_VERSION: latest | 4.50.1 | v4.50.1
  # =============================================================================

  local version="${YQ_VERSION:-latest}"
  version="${version#v}"

  local os="linux"
  local arch
  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) ui_msgbox "Error" "Unsupported architecture for yq: $(uname -m)"; return 1 ;;
  esac

  local platform="${os}_${arch}"
  local url
  if [[ "${version}" == "latest" ]]; then
    url="https://github.com/mikefarah/yq/releases/latest/download/yq_${platform}"
  else
    url="https://github.com/mikefarah/yq/releases/download/v${version}/yq_${platform}"
  fi

  ensure_state_dirs

  # Ensure downloader exists
  if ! need_cmd_quiet wget && ! need_cmd_quiet curl; then
    pkg_update_once
    pkg_install_pkgs wget curl
  fi

  info "Installing yq (${version}) from: ${url}"

  local td bin
  td="$(tmpdir_create)"
  bin="${td}/yq"

  if need_cmd_quiet wget; then
    wget -qO "${bin}" "${url}"
  else
    curl -fsSL -o "${bin}" "${url}"
  fi

  # Basic sanity check: non-empty file
  [[ -s "${bin}" ]] || { ui_msgbox "Error" "Downloaded yq binary is empty. URL: ${url}"; rm -rf -- "${td}"; return 1; }

  as_root install -m 0755 "${bin}" "${BIN_DIR}/yq"
  rm -rf -- "${td}"

  # Verify
  if command -v yq >/dev/null 2>&1; then
    yq --version >/dev/null 2>&1 || true
  fi
}

uninstall_yq_binary() {
  # =============================================================================
  # Uninstall yq (binary install)
  # =============================================================================
  as_root rm -f -- "${BIN_DIR}/yq" >/dev/null 2>&1 || true
  if is_marked_installed "yq"; then
    unmark_installed "yq"
  fi
}

# =============================================================================
# Docker convenience installer (get.docker.com)
# =============================================================================
install_docker_via_get_docker() {
  need_cmd_quiet curl || { ui_msgbox "Error" "curl is required to install Docker via get.docker.com"; return 1; }

  ensure_state_dirs

  local td script
  td="$(tmpdir_create)"
  script="${td}/get-docker.sh"

  log_line "Installing Docker via get.docker.com"
  curl -fsSL https://get.docker.com -o "${script}"
  as_root sh "${script}"
  rm -rf -- "${td}"
}

create_docker_remove_script() {
  ensure_state_dirs
  local out="${STATE_DIR}/remove-docker.sh"

  as_root bash -c "cat > '${out}' << 'EOF'
#!/usr/bin/env bash
# =============================================================================
# Remove Docker Engine (installed via get.docker.com convenience script)
# =============================================================================
set -Eeuo pipefail
log() { printf '%s %s\n' \"\$(date -Is)\" \"\$*\" >&2; }
require_root() { [[ \"\${EUID:-\$(id -u)}\" -eq 0 ]] || { echo \"Error: run as root (or via sudo).\" >&2; exit 1; }; }
stop_services() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl stop docker.service docker.socket containerd.service >/dev/null 2>&1 || true
    systemctl disable docker.service docker.socket >/dev/null 2>&1 || true
  fi
}
remove_packages() {
  local pkgs=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc)
  log \"Removing Docker packages (best-effort, not purge)\"
  apt-get update >/dev/null 2>&1 || true
  apt-get remove -y \"\${pkgs[@]}\" >/dev/null 2>&1 || true
  apt-get autoremove -y >/dev/null 2>&1 || true
  apt-get clean >/dev/null 2>&1 || true
}
remove_dirs() {
  log \"Removing Docker config directories (non-destructive by default)\"
  rm -rf /etc/docker || true
  if [[ \"\${PURGE_DOCKER_DATA:-0}\" == \"1\" ]]; then
    log \"PURGE_DOCKER_DATA=1 set, removing Docker data directories (destructive)\"
    rm -rf /var/lib/docker /var/lib/containerd || true
  else
    log \"Docker data not removed. Set PURGE_DOCKER_DATA=1 to purge.\"
  fi
  local u home
  u=\"\${SUDO_USER:-}\"
  if [[ -n \"\$u\" ]]; then
    home=\"\$(getent passwd \"\$u\" | cut -d: -f6)\"
    [[ -n \"\$home\" && -d \"\$home\" ]] && rm -rf \"\$home/.docker\" || true
  fi
}
remove_repo_bits() {
  log \"Removing Docker repo list/keyring (best-effort)\"
  rm -f /etc/apt/sources.list.d/docker.list || true
  rm -f /etc/apt/keyrings/docker.gpg || true
  rm -f /usr/share/keyrings/docker-archive-keyring.gpg || true
  apt-get update >/dev/null 2>&1 || true
}
main() { require_root; stop_services; remove_packages; remove_dirs; remove_repo_bits; log \"Docker removal complete.\"; }
main \"\$@\"
EOF
chmod 0755 '${out}'"
}

remove_docker_via_get_docker() {
  if ! is_marked_installed "docker_cli"; then
    log_line "Docker not removed (not installed by this app manager)."
    return 0
  fi
  create_docker_remove_script
  as_root "${STATE_DIR}/remove-docker.sh"
  unmark_installed "docker_cli"
}

# =============================================================================
# Python installer (strategy: python) – kept aligned with your original logic
# =============================================================================
detect_os() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-}"
    OS_VERSION_ID="${VERSION_ID:-}"
    OS_CODENAME="${VERSION_CODENAME:-}"
  else
    OS_ID=""
    OS_VERSION_ID=""
    OS_CODENAME=""
  fi
}

ensure_cmd() { command -v "$1" >/dev/null 2>&1; }
is_python_version_target() { [[ "${PYTHON_TARGET}" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; }
python_major_minor_from_target() { echo "${PYTHON_TARGET}" | awk -F. '{print $1"."$2}'; }
python_cmd_from_major_minor() { echo "python$1"; }

install_python_target() {
  detect_os

  if [[ "${PYTHON_TARGET}" == "system" ]]; then
    log_line "Python target: system (distro python3)."
    return 0
  fi

  if [[ "${PYTHON_TARGET}" == "pyenv" ]]; then
    validate_pyenv_python_version_value "${PYENV_PYTHON_VERSION}" || {
      ui_msgbox "Invalid value" "PYENV_PYTHON_VERSION must be numeric (for example 3.13.1)."
      return 1
    }

    pkg_install_pkgs build-essential curl git ca-certificates xz-utils
    pkg_install_pkgs libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libffi-dev liblzma-dev tk-dev

    local target_user target_home
    target_user="${SUDO_USER:-$USER}"
    target_home="$(getent passwd "${target_user}" | cut -d: -f6)"
    [[ -n "${target_home}" && -d "${target_home}" ]] || { ui_msgbox "Error" "Could not determine home directory for user '${target_user}'."; return 1; }

    if [[ ! -d "${target_home}/.pyenv" ]]; then
      sudo -u "${target_user}" bash -lc 'curl -fsSL https://pyenv.run | bash'
    fi

    sudo -u "${target_user}" bash -lc '
      set -euo pipefail
      touch ~/.bashrc
      grep -q "PYENV_ROOT" ~/.bashrc || echo "export PYENV_ROOT=\"$HOME/.pyenv\"" >> ~/.bashrc
      grep -q "PATH=\"$PYENV_ROOT/bin" ~/.bashrc || echo "export PATH=\"$PYENV_ROOT/bin:$PATH\"" >> ~/.bashrc
      grep -q "eval \"$(pyenv init -)\"" ~/.bashrc || echo "eval \"$(pyenv init -)\"" >> ~/.bashrc
    '

    sudo -u "${target_user}" bash -lc "
      set -euo pipefail
      export PYENV_ROOT=\"\$HOME/.pyenv\"
      export PATH=\"\$PYENV_ROOT/bin:\$PATH\"
      eval \"\$(pyenv init -)\"
      pyenv install -s ${PYENV_PYTHON_VERSION}
      pyenv global ${PYENV_PYTHON_VERSION}
      python --version
    "
    return 0
  fi

  if is_python_version_target; then
    if [[ "${OS_ID}" != "ubuntu" ]]; then
      ui_msgbox "Not supported" "PYTHON_TARGET=${PYTHON_TARGET} apt-based installs are supported on Ubuntu only. Use PYTHON_TARGET=pyenv on Debian."
      return 1
    fi

    local mm pycmd
    mm="$(python_major_minor_from_target)"
    pycmd="$(python_cmd_from_major_minor "${mm}")"

    pkg_install_pkgs software-properties-common
    if ! grep -R "ppa:deadsnakes/ppa" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | grep -q .; then
      as_root add-apt-repository -y ppa:deadsnakes/ppa
    fi

    pkg_update_once
    pkg_install_pkgs "${pycmd}" "${pycmd}-venv" "${pycmd}-dev" || {
      ui_msgbox "Install failed" "${pycmd} not available. Consider PYTHON_TARGET=pyenv."
      return 1
    }
    ensure_cmd "${pycmd}" || { ui_msgbox "Error" "${pycmd} not found after installation."; return 1; }
    "${pycmd}" --version || true
    return 0
  fi

  ui_msgbox "Invalid value" "Unknown PYTHON_TARGET '${PYTHON_TARGET}'. Use system, pyenv, or 3.13 / 3.13.1 / 3.14 ..."
  return 1
}

verify_python_target() {
  if [[ "${PYTHON_TARGET}" == "system" ]]; then
    ensure_cmd python3 || { ui_msgbox "Error" "python3 not available after install."; return 1; }
    return 0
  fi

  if [[ "${PYTHON_TARGET}" == "pyenv" ]]; then
    local target_user
    target_user="${SUDO_USER:-$USER}"
    sudo -u "${target_user}" bash -lc 'set -euo pipefail; command -v pyenv >/dev/null 2>&1; pyenv versions >/dev/null 2>&1' || {
      ui_msgbox "Error" "PYTHON_TARGET=pyenv requested but pyenv is not available for the user."
      return 1
    }
    return 0
  fi

  if is_python_version_target; then
    local mm pycmd
    mm="$(python_major_minor_from_target)"
    pycmd="$(python_cmd_from_major_minor "${mm}")"
    ensure_cmd "${pycmd}" || { ui_msgbox "Error" "PYTHON_TARGET=${PYTHON_TARGET} requested but ${pycmd} is not available."; return 1; }
    return 0
  fi
}

# =============================================================================
# Strategy dispatch
# =============================================================================
install_by_strategy() {
  local key="$1" pkgs_csv="$2" strategy="$3"
  case "${strategy:-apt}" in
    apt)
      local -a pkgs_arr=(); pkgs_csv_to_array "${pkgs_csv}" pkgs_arr
      pkg_install_pkgs "${pkgs_arr[@]}"
      ;;
    hashicorp_repo)
      ensure_hashicorp_repo
      pkg_update_once
      local -a pkgs_arr=(); pkgs_csv_to_array "${pkgs_csv}" pkgs_arr
      pkg_install_pkgs "${pkgs_arr[@]}"
      ;;
    docker_script)
      install_docker_via_get_docker
      ;;
    binary)
      ensure_state_dirs
      case "${key}" in
        helm) install_helm_binary ;;
        kubectl) install_kubectl_binary ;;
        *) ui_msgbox "Error" "Binary strategy not implemented for key '${key}'"; return 1 ;;
      esac
      ;;
    python)
      local -a pkgs_arr=(); pkgs_csv_to_array "${pkgs_csv}" pkgs_arr
      pkg_install_pkgs "${pkgs_arr[@]}"
      install_python_target
      verify_python_target
      ;;
    github_cli_repo)
      ensure_github_cli_repo
      pkg_update_once
      local -a pkgs_arr=(); pkgs_csv_to_array "${pkgs_csv}" pkgs_arr
      pkg_install_pkgs "${pkgs_arr[@]}"
      ;;
    nvm)
      ensure_nodesource_repo
      ;;
    mongodb_repo)
      ensure_mongodb_repo
      pkg_update_once
      local -a pkgs_arr=(); pkgs_csv_to_array "${pkgs_csv}" pkgs_arr
      pkg_install_pkgs "${pkgs_arr[@]}"
      # Optional: enable/start mongod when systemd exists
      if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        as_root systemctl enable mongod >/dev/null 2>&1 || true
        as_root systemctl start mongod >/dev/null 2>&1 || true
      fi
      ;;
    grafana_repo)
      ensure_grafana_repo
      pkg_update_once
      local -a pkgs_arr=(); pkgs_csv_to_array "${pkgs_csv}" pkgs_arr
      pkg_install_pkgs "${pkgs_arr[@]}"
      ;;
    yq_binary)
      install_yq_binary
      ;;
    sops_binary)
      install_sops_binary
      ;;
    *)
      ui_msgbox "Error" "Unknown strategy '${strategy}' for key '${key}'"
      return 1
      ;;
  esac
}

remove_by_strategy() {
  local key="$1" _pkgs_csv_unused="$2" strategy="$3"
  case "${strategy:-apt}" in
    apt|hashicorp_repo|python)
      if is_marked_installed "${key}"; then
        local marked_csv; marked_csv="$(marker_get_packages_compat_csv "${key}" || true)"
        local -a marked_arr=(); pkgs_csv_to_array "${marked_csv}" marked_arr
        ((${#marked_arr[@]})) && pkg_remove_pkgs "${marked_arr[@]}"
        unmark_installed "${key}"
      fi
      ;;
    binary)
      case "${key}" in
        helm) remove_helm_binary ;;
        kubectl) remove_kubectl_binary ;;
        *) ui_msgbox "Error" "Binary removal not implemented for key '${key}'"; return 1 ;;
      esac
      ;;
    docker_script)
      remove_docker_via_get_docker
      ;;
    github_cli_repo)
      # Conservative remove based on marker
      if is_marked_installed "${key}"; then
        local marked_csv; marked_csv="$(marker_get_packages_compat_csv "${key}" || true)"
        local -a marked_arr=(); pkgs_csv_to_array "${marked_csv}" marked_arr
        ((${#marked_arr[@]})) && pkg_remove_pkgs "${marked_arr[@]}"
        unmark_installed "${key}"
      fi
      ;;
    nvm)
      # Uninstall per-user NVM install (best-effort)
      if is_marked_installed "${key}"; then
        uninstall_nvm_node
      fi
      ;;
    mongodb_repo)
      if is_marked_installed "${key}"; then
        if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
          as_root systemctl stop mongod >/dev/null 2>&1 || true
          as_root systemctl disable mongod >/dev/null 2>&1 || true
        fi
        local marked_csv; marked_csv="$(marker_get_packages_compat_csv "${key}" || true)"
        local -a marked_arr=(); pkgs_csv_to_array "${marked_csv}" marked_arr
        ((${#marked_arr[@]})) && pkg_remove_pkgs "${marked_arr[@]}"
        unmark_installed "${key}"
      fi
      ;;
    grafana_repo)
      if is_marked_installed "${key}"; then
        uninstall_grafana_alloy
        unmark_installed "${key}"
      fi
      ;;
    yq_binary)
      if is_marked_installed "${key}"; then
        uninstall_yq_binary
      fi
      ;;
    sops_binary)
      if is_marked_installed "${key}"; then
        uninstall_sops_binary
      fi
      ;;
    *)
      ui_msgbox "Error" "Unknown strategy '${strategy}' for key '${key}'"
      return 1
      ;;
  esac
}

# =============================================================================
# UI flows
# =============================================================================
save_selections_from_ui_output() {
  local selected="$1"
  declare -A chosen=()
  local k

  # ui_checklist returns a space-delimited list of selected tags
  for k in ${selected}; do chosen["$k"]=1; done

  local row type key label def pkgs_csv desc strategy version_var
  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    validate_key "${key}" || continue
    if [[ -n "${chosen[$key]:-}" ]]; then
      printf -v "$(key_to_var "${key}")" '%s' "1"
    else
      printf -v "$(key_to_var "${key}")" '%s' "0"
    fi
  done

  write_env_file "Selections updated from UI" "from_ui" ""
}

run_checklist() {
  local -a items=()
  local row type key label def pkgs_csv desc strategy version_var
  local heading_count=0
  local blank_count=0
  local status

  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
    case "${type}" in
      HEADING)
        heading_count=$((heading_count + 1))
        items+=( "__hdr_${heading_count}" "=== ${key} ===" "off" )
        ;;
      BLANK)
        blank_count=$((blank_count + 1))
        items+=( "__blk_${blank_count}" " " "off" )
        ;;
      APP)
        validate_key "${key}" || continue
        if [[ "$(get_selection_value "${key}")" == "1" ]]; then status="on"; else status="off"; fi
        items+=( "${key}" "${label} | ${desc}" "${status}" )
        ;;
    esac
  done

  local raw=""
  ui_checklist "Select Applications" "Space toggles, arrows move. Cancel returns to menu." raw "${items[@]}"
  [[ -n "${raw}" ]] || return 0

  # Filter out headings/blanks
  local filtered=""
  local k
  for k in ${raw}; do
    [[ "${k}" == __hdr_* || "${k}" == __blk_* ]] && continue
    filtered+="${k} "
  done
  filtered="$(echo "${filtered}" | xargs || true)"

  save_selections_from_ui_output "${filtered}"
}

apply_profile_replace() { write_env_file "Profile applied (replace): $1" "replace" "$1"; }
apply_profile_add() { write_env_file "Profile applied (add): $1" "add" "$1"; }

choose_and_apply_profile_replace() {
  local choice=""
  ui_menu "Apply Profile (Replace)" "Choose a profile (overwrites selections and profile pins):" choice \
    basic "Core ops baseline" \
    dev "Developer tooling (build/runtime)" \
    automation "Ansible/Terraform/Packer focus" \
    platform "Automation + containers/K8s CLI" \
    database "Databases and data services" \
    observability "Observability tooling" \
    security "Security tooling" \
    all "All profile apps (unique union)"

  [[ -n "${choice}" ]] || return 0

  if ui_confirm "Confirm Profile Replace" "Apply profile '${choice}' in REPLACE mode?\n\nOverwrites selections and profile version pins.\n\nFile:\n${ENV_FILE}"; then
    apply_profile_replace "${choice}"
    ui_msgbox "Done" "Profile '${choice}' applied (replace)."
  fi
}

choose_and_apply_profile_add() {
  local choice=""
  ui_menu "Apply Profile (Add)" "Choose a profile (adds apps, overwrites profile pins):" choice \
    basic "Core ops baseline" \
    dev "Developer tooling (build/runtime)" \
    automation "Ansible/Terraform/Packer focus" \
    platform "Automation + containers/K8s CLI" \
    database "Databases and data services" \
    observability "Observability tooling" \
    security "Security tooling" \
    all "All profile apps (unique union)"

  [[ -n "${choice}" ]] || return 0

  if ui_confirm "Confirm Profile Add" "Apply profile '${choice}' in ADD mode?\n\nKeeps selections, adds apps, overwrites profile version pins.\n\nFile:\n${ENV_FILE}"; then
    apply_profile_add "${choice}"
    ui_msgbox "Done" "Profile '${choice}' applied (add)."
  fi
}

edit_version_pins() {
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

  write_env_file "Version pins updated from UI" "from_ui" ""
  ui_msgbox "Saved" "Version pins saved."
}

# =============================================================================
# Function: audit_selected_apps
# Purpose : Dynamically audit ONLY items marked for installation in app_install_list.env
# Notes   :
#   - Reads ${ENV_FILE} directly (no reliance on sourced APP_* vars for selection)
#   - Builds a dynamic dpkg package list from APP_CATALOGUE for selected=1 apps
#   - Checks dpkg status for apt-delivered packages
#   - Separately audits non-dpkg strategies (binary, yq/sops, docker, nvm) in a
#     lightweight, best-effort way
# =============================================================================
audit_selected_apps() {
  local env_file="${ENV_FILE}"

  if [[ ! -f "${env_file}" ]]; then
    ui_msgbox "Audit error" "Env file not found:\n\n${env_file}\n\nRun Apply or create selections first."
    return 1
  fi

  local ok_lines="" fail_lines=""
  local -a selected_keys=()
  local -a dpkg_packages=()
  local -a tmp_pkgs=()

  # Determine target user for per-user installs (NVM, pyenv, etc.)
  local target_user target_home
  target_user="${SUDO_USER:-$USER}"
  target_home="$(getent passwd "${target_user}" | cut -d: -f6)"
  [[ -n "${target_home}" && -d "${target_home}" ]] || target_home=""

  local has_systemd=0
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    has_systemd=1
  fi

  info "Audit started. Reading selections from: ${env_file}"
  info "Audit target user: ${target_user} (home: ${target_home:-unknown})"

  # ---------------------------------------------------------------------------
  # Step 1: Read ONLY items marked for installation (APP_*=1) from ENV_FILE
  #         Convert APP_FOO_BAR -> foo_bar (matches your catalogue keys)
  # ---------------------------------------------------------------------------
  while IFS='=' read -r k v; do
    [[ -z "${k}" || "${k}" =~ ^[[:space:]]*# ]] && continue
    [[ "${k}" =~ ^APP_ ]] || continue
    [[ "${v}" == "1" ]] || continue

    # APP_OPENSSH -> openssh ; APP_BUILD_ESSENTIAL -> build_essential
    local key
    key="${k#APP_}"
    key="$(printf '%s' "${key}" | tr '[:upper:]' '[:lower:]')"
    selected_keys+=("${key}")
  done < "${env_file}"

  if [[ "${#selected_keys[@]}" -eq 0 ]]; then
    ui_msgbox "Audit" "No applications are marked for installation in:\n\n${env_file}"
    return 0
  fi

  # ---------------------------------------------------------------------------
  # Helper: find a catalogue row by key and return its fields
  # ---------------------------------------------------------------------------
  _catalogue_get_row_by_key() {
    local want_key="$1"
    local row type key label def pkgs_csv desc strategy version_var
    for row in "${APP_CATALOGUE[@]}"; do
      IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
      [[ "${type}" == "APP" ]] || continue
      [[ "${key}" == "${want_key}" ]] || continue
      printf '%s\n' "${row}"
      return 0
    done
    return 1
  }

  # ---------------------------------------------------------------------------
  # Step 2: Build dynamic dpkg package list for selected apps
  #         Only include strategies that are package-based and have pkgs_csv
  # ---------------------------------------------------------------------------
  local key row type label def pkgs_csv desc strategy version_var
  for key in "${selected_keys[@]}"; do
    row="$(_catalogue_get_row_by_key "${key}" || true)"
    if [[ -z "${row}" ]]; then
      warn "Audit NOTE: selected key not in catalogue: ${key}"
      ok_lines+="${key} (not in catalogue)\n"
      continue
    fi

    IFS='|' read -r type _k label def pkgs_csv desc strategy version_var <<<"${row}"
    strategy="${strategy:-apt}"

    case "${strategy}" in
      apt|hashicorp_repo|python|github_cli_repo|mongodb_repo|grafana_repo)
        if [[ -n "${pkgs_csv}" ]]; then
          tmp_pkgs=()
          pkgs_csv_to_array "${pkgs_csv}" tmp_pkgs
          ((${#tmp_pkgs[@]})) && dpkg_packages+=("${tmp_pkgs[@]}")
        else
          ok_lines+="${key} (no dpkg packages)\n"
        fi
        ;;
      *)
        # Non-dpkg strategies are handled in Step 4
        ;;
    esac
  done

  # De-duplicate dpkg packages
  local -a dpkg_unique=()
  if ((${#dpkg_packages[@]})); then
    unique_pkgs dpkg_packages dpkg_unique
  fi

  # ---------------------------------------------------------------------------
  # Step 3: Audit dpkg packages (dynamic list, only selected=1 apps)
  #         Uses the dpkg-query loop pattern you supplied
  # ---------------------------------------------------------------------------
  if ((${#dpkg_unique[@]})); then
    info "Audit: dpkg package checks count=${#dpkg_unique[@]}"

    local PKG
    for PKG in "${dpkg_unique[@]}"; do
      dpkg-query -W --showformat='${Status}\n' "${PKG}" 2>/dev/null | grep "install ok installed" >/dev/null
      if [[ $? -eq 0 ]]; then
        ok "Audit OK: package installed: ${PKG}"
        ok_lines+="* ${PKG} is installed.\n"
      else
        warn "Audit FAIL: package NOT installed: ${PKG}"
        fail_lines+="* ${PKG} is NOT installed.\n"
      fi
    done
  else
    info "Audit: no dpkg packages to check for selected apps."
  fi

  # ---------------------------------------------------------------------------
  # Step 4: Audit non-dpkg strategies for selected apps (best-effort)
  #         Keeps audit meaningful for helm/kubectl/yq/sops/docker/nvm
  # ---------------------------------------------------------------------------
  for key in "${selected_keys[@]}"; do
    row="$(_catalogue_get_row_by_key "${key}" || true)"
    [[ -n "${row}" ]] || continue

    IFS='|' read -r type _k label def pkgs_csv desc strategy version_var <<<"${row}"
    strategy="${strategy:-apt}"

    case "${strategy}" in
      binary)
        case "${key}" in
          helm)
            if command -v helm >/dev/null 2>&1; then
              ok "Audit OK: helm binary present"
              ok_lines+="helm (binary present)\n"
            else
              warn "Audit FAIL: helm binary missing"
              fail_lines+="helm (missing binary)\n"
            fi
            ;;
          kubectl)
            if command -v kubectl >/dev/null 2>&1; then
              ok "Audit OK: kubectl binary present"
              ok_lines+="kubectl (binary present)\n"
            else
              warn "Audit FAIL: kubectl binary missing"
              fail_lines+="kubectl (missing binary)\n"
            fi
            ;;
          *)
            if command -v "${key}" >/dev/null 2>&1; then
              ok "Audit OK: binary present for key=${key}"
              ok_lines+="${key} (binary present)\n"
            else
              warn "Audit FAIL: binary missing for key=${key}"
              fail_lines+="${key} (missing binary)\n"
            fi
            ;;
        esac
        ;;

      yq_binary)
        if command -v yq >/dev/null 2>&1; then
          ok "Audit OK: yq binary present"
          ok_lines+="yq (binary present)\n"
        else
          warn "Audit FAIL: yq binary missing"
          fail_lines+="yq (missing binary)\n"
        fi
        ;;

      sops_binary)
        if command -v sops >/dev/null 2>&1; then
          ok "Audit OK: sops binary present"
          ok_lines+="sops (binary present)\n"
        else
          warn "Audit FAIL: sops binary missing"
          fail_lines+="sops (missing binary)\n"
        fi
        ;;

      docker_script)
        if command -v docker >/dev/null 2>&1; then
          ok "Audit OK: docker CLI present"
          ok_lines+="docker_cli (docker present)\n"
        else
          warn "Audit FAIL: docker CLI not found"
          fail_lines+="docker_cli (docker not found)\n"
        fi
        ;;

      nvm)
        if [[ -z "${target_home}" ]]; then
          warn "Audit FAIL: nodejs (cannot determine target home for ${target_user})"
          fail_lines+="nodejs (cannot determine target home for ${target_user})\n"
        elif [[ ! -d "${target_home}/.nvm" ]]; then
          warn "Audit FAIL: nodejs (nvm not found at ${target_home}/.nvm)"
          fail_lines+="nodejs (nvm not found at ${target_home}/.nvm)\n"
        else
          if sudo -u "${target_user}" bash -lc 'set -euo pipefail; export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"; command -v node >/dev/null; command -v npm >/dev/null; node -v >/dev/null; npm -v >/dev/null'; then
            ok "Audit OK: nodejs (nvm) node/npm available for ${target_user}"
            ok_lines+="nodejs (nvm ok)\n"
          else
            warn "Audit FAIL: nodejs (nvm present, but node/npm not available for ${target_user})"
            fail_lines+="nodejs (nvm present, but node/npm not available)\n"
          fi
        fi
        ;;

      apt|hashicorp_repo|python|github_cli_repo|mongodb_repo|grafana_repo)
        # Already handled via dpkg package list. Optional service notes (non-failing).
        if [[ "${has_systemd}" -eq 1 ]]; then
          if [[ "${key}" == "mongodb" ]]; then
            if systemctl is-active --quiet mongod; then
              ok "Audit OK: mongodb service mongod is active"
              ok_lines+="mongodb (mongod active)\n"
            else
              warn "Audit NOTE: mongodb service mongod not active"
              ok_lines+="mongodb (mongod not active)\n"
            fi
          elif [[ "${key}" == "grafana_alloy" ]]; then
            if systemctl is-active --quiet alloy; then
              ok "Audit OK: grafana_alloy service alloy is active"
              ok_lines+="grafana_alloy (alloy active)\n"
            else
              warn "Audit NOTE: grafana_alloy service alloy not active"
              ok_lines+="grafana_alloy (alloy not active)\n"
            fi
          fi
        fi
        ;;

      *)
        warn "Audit NOTE: no audit handler for strategy '${strategy}' (key=${key})"
        ok_lines+="${key} (no audit handler for ${strategy})\n"
        ;;
    esac
  done

  # ---------------------------------------------------------------------------
  # Step 5: Report
  # ---------------------------------------------------------------------------
  if [[ -n "${fail_lines}" ]]; then
    warn "Audit complete: missing items detected"
    ui_msgbox "Audit: Missing items" "Some items marked for installation did not verify as installed:\n\n$(printf '%b' "${fail_lines}")\nVerified OK:\n$(printf '%b' "${ok_lines}")"
    return 1
  fi

  ok "Audit complete: all items marked for installation verified"
  ui_msgbox "Audit: All installed" "All items marked for installation verified:\n\n$(printf '%b' "${ok_lines}")"
  return 0
}

apply_changes() {
  if ! ui_confirm "Apply Changes" "This will install selected apps.\nIt will remove only apps that were installed by this manager.\n\nProceed?"; then
    return 0
  fi

  apm_init_paths

  # Ensure lib/logging is in use and logging goes to this file
  logging_set_files "${LOG_FILE}"
  logging_begin_capture "${LOG_FILE}"
  trap 'logging_end_capture' RETURN

  info "Apply started. Log file: ${LOG_FILE}"

  ensure_pkg_mgr
  pkg_update_once
  load_env || true

  local row type key label def pkgs_csv desc strategy version_var
  local -a apt_install_list=()
  local need_hashicorp_repo=0

  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    validate_key "${key}" || continue
    strategy="${strategy:-apt}"

    if [[ "$(get_selection_value "${key}")" == "1" ]]; then
      case "${strategy}" in
        apt|hashicorp_repo)
          [[ "${strategy}" == "hashicorp_repo" ]] && need_hashicorp_repo=1
          local -a pkgs_arr=()
          pkgs_csv_to_array "${pkgs_csv}" pkgs_arr
          ((${#pkgs_arr[@]})) && apt_install_list+=("${pkgs_arr[@]}")
          ;;
      esac
    fi
  done

  if [[ "${need_hashicorp_repo}" -eq 1 ]]; then
    info "HashiCorp repo required. Ensuring repo is configured."
    ensure_hashicorp_repo
    pkg_update_once
  fi

  local -a apt_install_unique=()
  unique_pkgs apt_install_list apt_install_unique

  local -a apt_install_final=()
  local -a apt_missing=()
  filter_installable_apt_pkgs apt_install_unique apt_install_final apt_missing

  if ((${#apt_missing[@]})); then
    warn "Skipping missing apt packages: ${apt_missing[*]}"
    ui_msgbox "Skipped packages" "These packages are not available from current apt sources and were skipped:\n\n${apt_missing[*]}\n\nTip: Some items need a vendor repo or a binary install strategy."
  fi

  if ((${#apt_install_final[@]})); then
    info "Installing (apt/${PKG_MGR}) count=${#apt_install_final[@]}"
    pkg_install_pkgs "${apt_install_final[@]}"
  else
    info "No apt packages selected for installation."
  fi

  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    validate_key "${key}" || continue
    strategy="${strategy:-apt}"

    if [[ "$(get_selection_value "${key}")" == "1" ]]; then
      case "${strategy}" in
        apt|hashicorp_repo)
          if [[ -n "${pkgs_csv}" ]] && verify_pkgs_installed "${pkgs_csv}"; then
            mark_installed "${key}" "${strategy}" "${pkgs_csv}"
            ok "Marked installed: ${key}"
          else
            warn "Not marking ${key}; packages not fully installed: ${pkgs_csv}"
          fi
          ;;
      esac
    fi
  done

  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    validate_key "${key}" || continue
    strategy="${strategy:-apt}"

    case "${strategy}" in
      python|binary|docker_script)
        if [[ "$(get_selection_value "${key}")" == "1" ]]; then
          info "Installing (${strategy}): ${key}"
          install_by_strategy "${key}" "${pkgs_csv}" "${strategy}"
          mark_installed "${key}" "${strategy}" "${pkgs_csv}"
          ok "Installed: ${key}"
        else
          info "Removing (${strategy}): ${key}"
          remove_by_strategy "${key}" "${pkgs_csv}" "${strategy}"
        fi
        ;;
      apt|hashicorp_repo)
        if [[ "$(get_selection_value "${key}")" != "1" ]] && is_marked_installed "${key}"; then
          info "Removing (conservative ${strategy}): ${key}"
          remove_by_strategy "${key}" "${pkgs_csv}" "${strategy}"
        fi
        ;;
    esac
  done

  info "Autoremove via ${PKG_MGR}"
  pkg_autoremove

  audit_selected_apps || true
  ok "Apply complete."
  ui_msgbox "Complete" "Install / uninstall complete.\n\nLog:\n${LOG_FILE}"
}

_app_test_show_dialog() {
  local report_file="$1"
  local title="${2:-App install status}"

  if declare -F ui_textbox >/dev/null 2>&1; then
    ui_textbox "${title}" "${report_file}"
    return 0
  fi

  ui_msgbox "${title}" "Report saved to:\n${report_file}\n\n(ui_textbox not available, so not displaying full content)"
}


# =============================================================================
# Function: app_test
# Purpose : Produce an install-status report for all apps marked APP_<KEY>=1 in
#           ${ENV_FILE}, resolve via ${APP_CATALOGUE}, write to file, and display
#           via dialog UI (then return to menu).
#
# Notes
#   - Always returns 0 so it never breaks `make menu` or interactive flows.
# =============================================================================
app_test() {
  apm_init_paths

  local env_file="${ENV_FILE}"
  local out_file="${1:-${APPM_DIR}/app-test-status.txt}"

  if [[ ! -f "${env_file}" ]]; then
    printf 'ERROR: Env file not found: %s\n' "${env_file}" >"${out_file}"
    _app_test_show_dialog "${out_file}" "App install status"
    return 0
  fi

  # Determine target user for per-user installs (NVM, etc.)
  local target_user target_home
  target_user="${SUDO_USER:-$USER}"
  target_home="$(getent passwd "${target_user}" | cut -d: -f6)"
  [[ -n "${target_home}" && -d "${target_home}" ]] || target_home=""

  local has_systemd=0
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    has_systemd=1
  fi

  local -a selected_keys=()
  local -i failures=0

  # Step 1: Read items marked APP_*=1 from ENV_FILE and convert to catalogue keys
  while IFS='=' read -r k v; do
    [[ -z "${k}" || "${k}" =~ ^[[:space:]]*# ]] && continue
    [[ "${k}" =~ ^APP_ ]] || continue
    [[ "${v}" == "1" ]] || continue

    local key
    key="${k#APP_}"
    key="$(printf '%s' "${key}" | tr '[:upper:]' '[:lower:]')"
    selected_keys+=("${key}")
  done < "${env_file}"

  # Header
  {
    printf 'fouchger_homelab app_test report\n'
    printf 'Generated : %s\n' "$(date -Is)"
    printf 'Host      : %s\n' "$(hostname -f 2>/dev/null || hostname)"
    printf 'Env file  : %s\n' "${env_file}"
    printf 'User      : %s (home: %s)\n' "${target_user}" "${target_home:-unknown}"
    printf '\n'
  } >"${out_file}"

  if [[ "${#selected_keys[@]}" -eq 0 ]]; then
    printf 'No applications are marked for installation (APP_*=1).\n' >>"${out_file}"
    _app_test_show_dialog "${out_file}" "App install status"
    return 0
  fi

  # Helper: find a catalogue row by key
  _catalogue_get_row_by_key() {
    local want_key="$1"
    local row type key label def pkgs_csv desc strategy version_var
    for row in "${APP_CATALOGUE[@]}"; do
      IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
      [[ "${type}" == "APP" ]] || continue
      [[ "${key}" == "${want_key}" ]] || continue
      printf '%s\n' "${row}"
      return 0
    done
    return 1
  }

  # Package install check (dpkg)
  _dpkg_is_installed() {
    local pkg="$1"
    dpkg-query -W --showformat='${Status}\n' "${pkg}" 2>/dev/null | grep -q "install ok installed"
  }

  # Table header
  {
    printf '%-18s  %-14s  %-10s  %s\n' "APP_KEY" "STRATEGY" "STATUS" "DETAILS"
    printf '%-18s  %-14s  %-10s  %s\n' "------" "--------" "------" "-------"
  } >>"${out_file}"

  # Step 2: Resolve + test
  local key row type label def pkgs_csv desc strategy version_var
  for key in "${selected_keys[@]}"; do
    row="$(_catalogue_get_row_by_key "${key}" || true)"

    if [[ -z "${row}" ]]; then
      printf '%-18s  %-14s  %-10s  %s\n' "${key}" "-" "UNKNOWN" "Selected but not found in APP_CATALOGUE" >>"${out_file}"
      failures=$((failures + 1))
      continue
    fi

    IFS='|' read -r type _k label def pkgs_csv desc strategy version_var <<<"${row}"
    strategy="${strategy:-apt}"

    local status="OK"
    local details=""

    case "${strategy}" in
      apt|hashicorp_repo|python|github_cli_repo|mongodb_repo|grafana_repo)
        if [[ -z "${pkgs_csv}" ]]; then
          status="OK"
          details="No dpkg packages declared"
        else
          local -a pkgs_arr=()
          pkgs_csv_to_array "${pkgs_csv}" pkgs_arr

          local -a missing=()
          local pkg
          for pkg in "${pkgs_arr[@]}"; do
            if ! _dpkg_is_installed "${pkg}"; then
              missing+=("${pkg}")
            fi
          done

          if ((${#missing[@]})); then
            status="MISSING"
            details="Missing dpkg: ${missing[*]}"
          else
            status="OK"
            details="All dpkg packages installed"
          fi
        fi

        if [[ "${has_systemd}" -eq 1 ]]; then
          if [[ "${key}" == "mongodb" ]]; then
            systemctl is-active --quiet mongod \
              && details="${details}; service: mongod active" \
              || details="${details}; service: mongod not active"
          elif [[ "${key}" == "grafana_alloy" ]]; then
            systemctl is-active --quiet alloy \
              && details="${details}; service: alloy active" \
              || details="${details}; service: alloy not active"
          fi
        fi
        ;;

      binary)
        case "${key}" in
          helm)    command -v helm >/dev/null 2>&1    && status="OK" details="helm present"    || status="MISSING" details="helm not found in PATH" ;;
          kubectl) command -v kubectl >/dev/null 2>&1 && status="OK" details="kubectl present" || status="MISSING" details="kubectl not found in PATH" ;;
          *)       command -v "${key}" >/dev/null 2>&1 && status="OK" details="binary present (${key})" || status="MISSING" details="binary not found in PATH (${key})" ;;
        esac
        ;;

      yq_binary)
        command -v yq >/dev/null 2>&1 && status="OK" details="yq present" || status="MISSING" details="yq not found in PATH"
        ;;

      sops_binary)
        command -v sops >/dev/null 2>&1 && status="OK" details="sops present" || status="MISSING" details="sops not found in PATH"
        ;;

      docker_script)
        command -v docker >/dev/null 2>&1 && status="OK" details="docker present" || status="MISSING" details="docker not found in PATH"
        ;;

      nvm)
        if [[ -z "${target_home}" ]]; then
          status="MISSING"
          details="Cannot determine target home for ${target_user}"
        elif [[ ! -d "${target_home}/.nvm" ]]; then
          status="MISSING"
          details="nvm not found at ${target_home}/.nvm"
        else
          if sudo -u "${target_user}" bash -lc 'set -euo pipefail; export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"; command -v node >/dev/null; command -v npm >/dev/null; node -v >/dev/null; npm -v >/dev/null'; then
            status="OK"
            details="nvm ok; node/npm available"
          else
            status="MISSING"
            details="nvm present but node/npm not usable for ${target_user}"
          fi
        fi
        ;;

      *)
        status="UNKNOWN"
        details="No test handler for strategy '${strategy}'"
        ;;
    esac

    [[ "${status}" == "OK" ]] || failures=$((failures + 1))

    printf '%-18s  %-14s  %-10s  %s\n' \
      "${key}" "${strategy}" "${status}" "${details} | ${label}" >>"${out_file}"
  done

  # Footer
  {
    printf '\n'
    printf 'Summary\n'
    printf 'Selected apps : %s\n' "${#selected_keys[@]}"
    printf 'Failures      : %s\n' "${failures}"
    printf 'Overall       : %s\n' "$([[ "${failures}" -eq 0 ]] && echo "PASS" || echo "FAIL")"
    printf '\n'
    printf 'Report saved  : %s\n' "${out_file}"
  } >>"${out_file}"

  _app_test_show_dialog "${out_file}" "App install status"
  return 0
}
