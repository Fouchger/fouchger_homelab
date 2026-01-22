#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/lxc/app_manager.sh
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
APPM_DIR="${STATE_DIR_DEFAULT}/lxc_app_manager"
ENV_FILE="${APPM_DIR}/app_install_list.env"
ENV_BACKUP_DIR="${APPM_DIR}/.backups"
LOG_FILE="${APPM_DIR}/app-manager.log"

STATE_DIR="/usr/local/share/ubuntu-lxc-app-manager"
MARKER_DIR="${STATE_DIR}/markers"
BIN_DIR="/usr/local/bin"

# =============================================================================
# Version pinning defaults (can be overridden by env file or exported env vars)
# =============================================================================
TERRAFORM_VERSION="${TERRAFORM_VERSION:-latest}"
PACKER_VERSION="${PACKER_VERSION:-latest}"
VAULT_VERSION="${VAULT_VERSION:-latest}"
HELM_VERSION="${HELM_VERSION:-latest}"
KUBECTL_VERSION="${KUBECTL_VERSION:-latest}"

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
  "APP|gh|[Build] gh (GitHub CLI)|ON|gh|GitHub CLI tool|apt|"
  "APP|python|[Build] Python tooling (versioned)|OFF|python3,python3-venv,pipx|Python runtime and tooling|python|PYTHON_TARGET"
  "APP|nodejs|[Build] Node.js (distro)|OFF|nodejs,npm|Node.js runtime|apt|"
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
  "APP|yq|[Infra] yq|OFF|yq|YAML processor|apt|"

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
  "APP|mongodb|[Data] MongoDB (distro)|OFF|mongodb|Document database (Ubuntu repo packaging varies)|apt|"

  "BLANK| "
  "HEADING|6. Observability and Diagnostics"
  "APP|nettools|[Obs] net-tools|OFF|net-tools|Legacy networking tools|apt|"
  "APP|iproute2|[Obs] iproute2|ON|iproute2|Modern networking tools|apt|"
  "APP|tcpdump|[Obs] tcpdump|OFF|tcpdump|Packet capture|apt|"
  "APP|strace|[Obs] strace|OFF|strace|Syscall tracing|apt|"
  "APP|grafana_agent|[Obs] Grafana Agent|OFF|grafana-agent|Telemetry agent (availability depends on repo)|apt|"

  "BLANK| "
  "HEADING|7. Security and Access Tooling"
  "APP|gpg|[Sec] GnuPG|ON|gnupg|Encryption and signing|apt|"
  "APP|pass|[Sec] pass|OFF|pass|Password store|apt|"
  "APP|vault|[Sec] Vault CLI|OFF|vault|Secrets management|hashicorp_repo|VAULT_VERSION"
  "APP|age|[Sec] age|OFF|age|Modern encryption|apt|"
  "APP|sops|[Sec] sops|OFF|sops|Secrets operations|apt|"
)

# =============================================================================
# Profiles (apps)
# =============================================================================
PROFILE_BASIC_KEYS=(openssh sudo curl wget rsync tmux htop btop chrony logrotate jq iproute2 gpg git gh)

PROFILE_DEV_KEYS=( "${PROFILE_BASIC_KEYS[@]}" build_essential make cmake python nodejs openjdk golang )
PROFILE_AUTOMATION_KEYS=( "${PROFILE_BASIC_KEYS[@]}" ansible terraform packer yq )
PROFILE_PLATFORM_KEYS=( "${PROFILE_AUTOMATION_KEYS[@]}" helm kubectl docker_cli podman_cli docker_compose tcpdump strace )
PROFILE_DATABASE_KEYS=( "${PROFILE_BASIC_KEYS[@]}" postgres mysql mariadb redis mongodb )
PROFILE_OBSERVABILITY_KEYS=( "${PROFILE_BASIC_KEYS[@]}" nettools grafana_agent )
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
    "PYTHON_TARGET" \
    "PYENV_PYTHON_VERSION"
}

default_for_version_var() {
  local var="$1"
  case "${var}" in
    PYTHON_TARGET) printf '%s' "${PYTHON_TARGET:-system}" ;;
    PYENV_PYTHON_VERSION) printf '%s' "${PYENV_PYTHON_VERSION:-3.13.1}" ;;
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
  mapfile -t out < <(printf '%s\n' "${!in_name}" | awk 'NF' | sort -u)
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
  apt_install nala || true
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

# =============================================================================
# HashiCorp repo (apt.releases.hashicorp.com)
# =============================================================================
ensure_hashicorp_repo() {
  if ! need_cmd_quiet curl || ! need_cmd_quiet gpg; then
    apt_install ca-certificates curl gnupg
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

audit_selected_apps() {
  load_env || true

  local ok_lines="" fail_lines=""
  local row type key label def pkgs_csv desc strategy version_var

  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    [[ "$(get_selection_value "${key}")" == "1" ]] || continue

    strategy="${strategy:-apt}"
    case "${strategy}" in
      apt|hashicorp_repo|python)
        if [[ -z "${pkgs_csv}" ]]; then
          ok_lines+="${key} (no packages)\n"
        elif verify_pkgs_installed "${pkgs_csv}"; then
          ok_lines+="${key}\n"
        else
          fail_lines+="${key} (missing: ${pkgs_csv})\n"
        fi
        ;;
      binary)
        if [[ "${key}" == "helm" ]]; then
          command -v helm >/dev/null 2>&1 && ok_lines+="helm\n" || fail_lines+="helm (missing binary)\n"
        elif [[ "${key}" == "kubectl" ]]; then
          command -v kubectl >/dev/null 2>&1 && ok_lines+="kubectl\n" || fail_lines+="kubectl (missing binary)\n"
        else
          ok_lines+="${key} (binary)\n"
        fi
        ;;
      docker_script)
        command -v docker >/dev/null 2>&1 && ok_lines+="docker_cli\n" || fail_lines+="docker_cli (docker not found)\n"
        ;;
    esac
  done

  if [[ -n "${fail_lines}" ]]; then
    ui_msgbox "Audit: Missing items" "Some selected apps did not verify as installed:\n\n$(printf '%b' "${fail_lines}")\nInstalled OK:\n$(printf '%b' "${ok_lines}")"
    return 1
  fi

  ui_msgbox "Audit: All installed" "All selected apps verified as installed:\n\n$(printf '%b' "${ok_lines}")"
  return 0
}

apply_changes() {
  if ! ui_confirm "Apply Changes" "This will install selected apps.\nIt will remove only apps that were installed by this manager.\n\nProceed?"; then
    return 0
  fi

  apm_init_paths
  ensure_pkg_mgr
  pkg_update_once
  load_env || true

  local row type key label def pkgs_csv desc strategy version_var
  local -a apt_install_list=()
  local need_hashicorp_repo=0

  # Collect apt/hashicorp installs (CSV-safe)
  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    validate_key "${key}" || continue
    strategy="${strategy:-apt}"

    if [[ "$(get_selection_value "${key}")" == "1" ]]; then
      case "${strategy}" in
        apt|hashicorp_repo)
          [[ "${strategy}" == "hashicorp_repo" ]] && need_hashicorp_repo=1
          local -a pkgs_arr=(); pkgs_csv_to_array "${pkgs_csv}" pkgs_arr
          ((${#pkgs_arr[@]})) && apt_install_list+=("${pkgs_arr[@]}")
          ;;
      esac
    fi
  done

  if [[ "${need_hashicorp_repo}" -eq 1 ]]; then
    ensure_hashicorp_repo
    pkg_update_once
  fi

  local -a apt_install_unique=()
  unique_pkgs apt_install_list apt_install_unique

  if ((${#apt_install_unique[@]})); then
    log_line "Installing (apt/${PKG_MGR}): ${apt_install_unique[*]}"
    pkg_install_pkgs "${apt_install_unique[@]}"
  else
    log_line "No apt packages selected for installation."
  fi

  # Mark apt/hashicorp keys only after verification
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
          else
            log_line "WARN: Not marking ${key}; packages not fully installed: ${pkgs_csv}"
          fi
          ;;
      esac
    fi
  done

  # Handle non-apt strategies and conservative removals
  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key label def pkgs_csv desc strategy version_var <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    validate_key "${key}" || continue
    strategy="${strategy:-apt}"

    case "${strategy}" in
      python|binary|docker_script)
        if [[ "$(get_selection_value "${key}")" == "1" ]]; then
          log_line "Installing (${strategy}): ${key}"
          install_by_strategy "${key}" "${pkgs_csv}" "${strategy}"
          mark_installed "${key}" "${strategy}" "${pkgs_csv}"
        else
          log_line "Removing (${strategy}): ${key}"
          remove_by_strategy "${key}" "${pkgs_csv}" "${strategy}"
        fi
        ;;
      apt|hashicorp_repo)
        if [[ "$(get_selection_value "${key}")" != "1" ]] && is_marked_installed "${key}"; then
          log_line "Removing (conservative ${strategy}): ${key}"
          remove_by_strategy "${key}" "${pkgs_csv}" "${strategy}"
        fi
        ;;
    esac
  done

  log_line "Autoremove via ${PKG_MGR}"
  pkg_autoremove

  audit_selected_apps || true
  ui_msgbox "Complete" "Install / uninstall complete.\n\nLog:\n${LOG_FILE}"
}

