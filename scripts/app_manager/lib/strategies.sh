#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/strategies.sh
# Created: 28/01/2026
# Updated: 28/01/2026
# Description: App Manager strategy handlers (install/uninstall) for questionnaire entries.
#
# Notes
#   - This file provides one dispatcher plus one handler per strategy.
#   - Catalogue provides these fields per app record:
#       key, label, default, packages_csv, description, strategy, version_var
#   - Strategies keep catalogue declarative. All prerequisites and repo work happens here.
#   - Conventions:
#       * Third-party APT keyrings go into /etc/apt/keyrings (mode 0755)
#       * Third-party APT list files go into /etc/apt/sources.list.d/
#       * Binaries install to /usr/local/bin
#   - Safety:
#       * Designed for set -Eeuo pipefail
#       * Functions return non-zero on failure with meaningful messages
#   - Extensibility:
#       * Add new strategy_* handlers and register them in strategy_apply()
# 
# Usage
#   mode="install" or "uninstall"
#   app_key, packages_csv, strategy, version_var_name come from the catalogue row
#   Command: strategy_apply "$mode" "$app_key" "$packages_csv" "$strategy" "$version_var_name"
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Logging helpers (caller can redirect into dialog output/log files as needed)
# -----------------------------------------------------------------------------
log_info() { printf '%s\n' "INFO: $*"; }
log_warn() { printf '%s\n' "WARN: $*" >&2; }
log_err()  { printf '%s\n' "ERROR: $*" >&2; }

# -----------------------------------------------------------------------------
# Common helpers
# -----------------------------------------------------------------------------
require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log_err "This operation must be run as root."
    return 1
  fi
}

ensure_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || mkdir -p "$dir"
}

csv_to_array() {
  # Convert comma-separated values into a bash array.
  # Usage: csv_to_array "$packages_csv" out_array
  local csv="${1:-}"
  local -n _out="$2"

  _out=()
  [[ -z "$csv" ]] && return 0

  IFS=',' read -r -a _out <<< "$csv"
}

apt_update_once() {
  # Idempotent-ish: skip update if we already did it in this run.
  if [[ "${_APP_MGR_APT_UPDATED:-0}" != "1" ]]; then
    log_info "Running apt-get update"
    apt-get update -y
    _APP_MGR_APT_UPDATED=1
  fi
}

apt_install_packages() {
  local packages_csv="${1:-}"
  local pkgs=()
  csv_to_array "$packages_csv" pkgs

  if (( ${#pkgs[@]} == 0 )); then
    log_warn "No packages provided for apt install."
    return 0
  fi

  apt_update_once
  log_info "Installing (apt): ${pkgs[*]}"
  apt-get install -y "${pkgs[@]}"
}

apt_remove_packages() {
  local packages_csv="${1:-}"
  local pkgs=()
  csv_to_array "$packages_csv" pkgs

  if (( ${#pkgs[@]} == 0 )); then
    log_warn "No packages provided for apt remove."
    return 0
  fi

  apt_update_once
  log_info "Removing (apt): ${pkgs[*]}"
  apt-get remove -y "${pkgs[@]}"
  # Keep autoremove conservative; caller can run a cleanup phase if desired.
}

ensure_apt_prereqs() {
  # Accepts packages_csv (comma-separated) and installs them via apt.
  local prereqs_csv="${1:-}"
  [[ -z "$prereqs_csv" ]] && return 0
  apt_install_packages "$prereqs_csv"
}

download_to() {
  # download_to <url> <dest_path>
  local url="$1"
  local dest="$2"

  ensure_dir "$(dirname "$dest")"
  rm -f "$dest"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    log_err "Neither curl nor wget is available to download $url"
    return 1
  fi
}

detect_arch() {
  # Returns values commonly used by upstream binary releases.
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64)  printf '%s' "amd64" ;;
    aarch64|arm64) printf '%s' "arm64" ;;
    armv7l)        printf '%s' "armv7" ;;
    *) log_err "Unsupported architecture: $arch"; return 1 ;;
  esac
}

detect_os() {
  # For binary release URLs (Linux only in this project context).
  printf '%s' "linux"
}

write_apt_repo_file() {
  # write_apt_repo_file <file_path> <content>
  local file="$1"
  local content="$2"
  ensure_dir "$(dirname "$file")"
  printf '%s\n' "$content" > "$file"
}

remove_if_exists() {
  local path="$1"
  [[ -e "$path" ]] && rm -f "$path"
}

ubuntu_codename() {
  local codename=""
  codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
  [[ -n "$codename" ]] || { log_err "Unable to determine Ubuntu codename"; return 1; }
  printf '%s' "$codename"
}

# -----------------------------------------------------------------------------
# Optional run-as-target support (preferred for per-user installers like NVM)
# If your repo provides run_as_target(), source it before calling strategy_apply.
# Conventions:
#   APP_MGR_TARGET_USER : username to run per-user installers under (default: SUDO_USER)
# -----------------------------------------------------------------------------
app_mgr_target_user() {
  if [[ -n "${APP_MGR_TARGET_USER:-}" ]]; then
    printf '%s' "$APP_MGR_TARGET_USER"
    return 0
  fi
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    printf '%s' "$SUDO_USER"
    return 0
  fi
  # Fallback: current user (may be root, which is not ideal for NVM)
  printf '%s' "$(id -un)"
}

run_as_user_if_possible() {
  # run_as_user_if_possible <user> <command...>
  # If run_as_target is available, use it. Otherwise fallback to sudo -u.
  local user="$1"; shift
  if declare -F run_as_target >/dev/null 2>&1; then
    run_as_target "$user" "$@"
    return $?
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo -u "$user" -- "$@"
    return $?
  fi
  log_err "No run_as_target or sudo available to run command as user '$user'"
  return 1
}

# -----------------------------------------------------------------------------
# Strategy dispatcher
# -----------------------------------------------------------------------------
strategy_apply() {
  # strategy_apply <install|uninstall> <app_key> <packages_csv> <strategy> <version_var_name>
  local mode="$1"
  local app_key="$2"
  local packages_csv="${3:-}"
  local strategy="$4"
  local version_var_name="${5:-}"

  require_root

  case "$strategy" in
    apt)              strategy_apt "$mode" "$app_key" "$packages_csv" ;;
    github_cli_repo)  strategy_github_cli_repo "$mode" "$app_key" "$packages_csv" ;;
    hashicorp_repo)   strategy_hashicorp_repo "$mode" "$app_key" "$packages_csv" ;;
    docker_apt_repo)  strategy_docker_apt_repo "$mode" "$app_key" "$packages_csv" ;;
    grafana_repo)     strategy_grafana_repo "$mode" "$app_key" "$packages_csv" ;;
    mongodb_repo)     strategy_mongodb_repo "$mode" "$app_key" "$packages_csv" ;;
    binary)           strategy_binary "$mode" "$app_key" "$version_var_name" ;;
    yq_binary)        strategy_yq_binary "$mode" "$version_var_name" ;;
    sops_binary)      strategy_sops_binary "$mode" "$version_var_name" ;;
    python)           strategy_python "$mode" "$app_key" "$packages_csv" "$version_var_name" ;;
    nvm)              strategy_nvm "$mode" "$version_var_name" ;;
    *) log_err "Unknown strategy '$strategy' for app '$app_key'"; return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Strategy: apt
# -----------------------------------------------------------------------------
strategy_apt() {
  local mode="$1"
  local _app_key="$2"
  local packages_csv="$3"

  case "$mode" in
    install)   apt_install_packages "$packages_csv" ;;
    uninstall) apt_remove_packages "$packages_csv" ;;
    *) log_err "Invalid mode '$mode' (apt)"; return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Strategy: github_cli_repo (gh)
# -----------------------------------------------------------------------------
strategy_github_cli_repo() {
  local mode="$1"
  local _app_key="$2"
  local packages_csv="$3"

  # Standardise file names so uninstall is predictable.
  local keyring="/etc/apt/keyrings/githubcli-archive-keyring.gpg"
  local listfile="/etc/apt/sources.list.d/github-cli.list"

  case "$mode" in
    install)
      ensure_apt_prereqs "ca-certificates,curl,gnupg"
      ensure_dir "/etc/apt/keyrings"
      chmod 0755 /etc/apt/keyrings

      # Key + repo based on GitHub CLI installation guidance (Ubuntu/Debian).
      download_to "https://cli.github.com/packages/githubcli-archive-keyring.gpg" "$keyring"
      chmod 0644 "$keyring"

      # Ubuntu codename from /etc/os-release (noble for 24.04).
      # We avoid lsb_release dependency.
      local codename=""
      codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
      [[ -n "$codename" ]] || { log_err "Unable to determine Ubuntu codename"; return 1; }

      write_apt_repo_file "$listfile" \
        "deb [arch=$(dpkg --print-architecture) signed-by=$keyring] https://cli.github.com/packages stable main"

      apt_install_packages "$packages_csv"
      ;;

    uninstall)
      apt_remove_packages "$packages_csv"
      # Optional cleanup: remove repo artefacts.
      remove_if_exists "$listfile"
      remove_if_exists "$keyring"
      ;;

    *) log_err "Invalid mode '$mode' (github_cli_repo)"; return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Strategy: hashicorp_repo (terraform/packer/vault via apt)
# -----------------------------------------------------------------------------
strategy_hashicorp_repo() {
  local mode="$1"
  local _app_key="$2"
  local packages_csv="$3"

  local keyring="/usr/share/keyrings/hashicorp-archive-keyring.gpg"
  local listfile="/etc/apt/sources.list.d/hashicorp.list"

  case "$mode" in
    install)
      ensure_apt_prereqs "ca-certificates,gnupg,curl"
      ensure_dir "/usr/share/keyrings"

      # HashiCorp provides repo + key steps; keep implementation stable.
      # Key is ASCII-armoured; dearmor to keyring.
      local tmpkey="/tmp/hashicorp.asc"
      download_to "https://apt.releases.hashicorp.com/gpg" "$tmpkey"
      gpg --dearmor < "$tmpkey" > "$keyring"
      chmod 0644 "$keyring"
      rm -f "$tmpkey"

      local codename
      codename="$(ubuntu_codename)"

      write_apt_repo_file "$listfile" \
        "deb [signed-by=$keyring] https://apt.releases.hashicorp.com $codename main"

      apt_install_packages "$packages_csv"
      ;;

    uninstall)
      apt_remove_packages "$packages_csv"
      # Optional cleanup: remove repo artefacts.
      remove_if_exists "$listfile"
      remove_if_exists "$keyring"
      ;;

    *) log_err "Invalid mode '$mode' (hashicorp_repo)"; return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Strategy: docker_apt_repo (Docker Engine + plugins via apt)
# -----------------------------------------------------------------------------
strategy_docker_apt_repo() {
  local mode="$1"
  local _app_key="$2"
  local packages_csv="$3"

  local keyring="/etc/apt/keyrings/docker.gpg"
  local listfile="/etc/apt/sources.list.d/docker.list"

  case "$mode" in
    install)
      ensure_apt_prereqs "ca-certificates,curl,gnupg"
      ensure_dir "/etc/apt/keyrings"
      chmod 0755 /etc/apt/keyrings

      # Remove known conflicting packages conservatively (Docker suggests removing unofficial variants).
      # If packages are absent, apt will ignore.
      apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc || true

      download_to "https://download.docker.com/linux/ubuntu/gpg" "/tmp/docker.gpg"
      gpg --dearmor < "/tmp/docker.gpg" > "$keyring"
      chmod 0644 "$keyring"
      rm -f "/tmp/docker.gpg"

      local codename
      codename="$(ubuntu_codename)"

      write_apt_repo_file "$listfile" \
        "deb [arch=$(dpkg --print-architecture) signed-by=$keyring] https://download.docker.com/linux/ubuntu $codename stable"

      apt_install_packages "$packages_csv"
      ;;

    uninstall)
      apt_remove_packages "$packages_csv"
      # Optional cleanup: remove repo artefacts.
      remove_if_exists "$listfile"
      remove_if_exists "$keyring"
      # Data cleanup is intentionally not done here.
      ;;

    *) log_err "Invalid mode '$mode' (docker_apt_repo)"; return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Strategy: grafana_repo (Alloy via apt)
# -----------------------------------------------------------------------------
strategy_grafana_repo() {
  local mode="$1"
  local _app_key="$2"
  local packages_csv="$3"

  local keyring="/etc/apt/keyrings/grafana.gpg"
  local listfile="/etc/apt/sources.list.d/grafana.list"

  case "$mode" in
    install)
      ensure_apt_prereqs "ca-certificates,curl,gnupg"
      ensure_dir "/etc/apt/keyrings"
      chmod 0755 /etc/apt/keyrings

      download_to "https://apt.grafana.com/gpg.key" "/tmp/grafana.gpg"
      gpg --dearmor < "/tmp/grafana.gpg" > "$keyring"
      chmod 0644 "$keyring"
      rm -f "/tmp/grafana.gpg"

      # Grafana repo is not codename-specific for many packages.
      write_apt_repo_file "$listfile" \
        "deb [signed-by=$keyring] https://apt.grafana.com stable main"

      apt_install_packages "$packages_csv"
      ;;

    uninstall)
      apt_remove_packages "$packages_csv"
      remove_if_exists "$listfile"
      remove_if_exists "$keyring"
      ;;

    *) log_err "Invalid mode '$mode' (grafana_repo)"; return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Strategy: mongodb_repo (MongoDB Community via apt)
# -----------------------------------------------------------------------------
strategy_mongodb_repo() {
  local mode="$1"
  local _app_key="$2"
  local packages_csv="$3"

  # You may want to standardise a single keyring name even across series.
  local keyring="/etc/apt/keyrings/mongodb.gpg"
  local listfile="/etc/apt/sources.list.d/mongodb-org.list"

  # Series is typically set by env var MONGODB_SERIES, e.g. "7.0"
  local series="${MONGODB_SERIES:-}"

  case "$mode" in
    install)
      [[ -n "$series" ]] || { log_err "MONGODB_SERIES is required for mongodb_repo (e.g. 7.0)"; return 1; }

      ensure_apt_prereqs "ca-certificates,curl,gnupg"
      ensure_dir "/etc/apt/keyrings"
      chmod 0755 /etc/apt/keyrings

      # MongoDB provides series-specific repo endpoints.
      download_to "https://pgp.mongodb.com/server-${series}.asc" "/tmp/mongodb.asc"
      gpg --dearmor < "/tmp/mongodb.asc" > "$keyring"
      chmod 0644 "$keyring"
      rm -f "/tmp/mongodb.asc"

      local codename
      codename="$(ubuntu_codename)"

      write_apt_repo_file "$listfile" \
        "deb [arch=$(dpkg --print-architecture) signed-by=$keyring] https://repo.mongodb.org/apt/ubuntu $codename/mongodb-org/${series} multiverse"

      apt_install_packages "$packages_csv"
      ;;

    uninstall)
      apt_remove_packages "$packages_csv"
      remove_if_exists "$listfile"
      remove_if_exists "$keyring"
      ;;

    *) log_err "Invalid mode '$mode' (mongodb_repo)"; return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Strategy: binary (generic for helm/kubectl, extendable)
# -----------------------------------------------------------------------------
strategy_binary() {
  # strategy_binary <install|uninstall> <app_key> <version_var_name>
  local mode="$1"
  local app_key="$2"
  local version_var_name="${3:-}"

  local os arch version bin_path
  os="$(detect_os)"
  arch="$(detect_arch)"

  # Resolve version from env var if provided. Some apps can optionally implement "latest stable".
  if [[ -n "$version_var_name" ]]; then
    # shellcheck disable=SC2154
    version="${!version_var_name:-}"
  else
    version=""
  fi

  case "$app_key" in
    helm)
      bin_path="/usr/local/bin/helm"
      case "$mode" in
        install)
          [[ -n "$version" ]] || { log_err "HELM_VERSION is required for helm (e.g. v3.15.4)"; return 1; }
          local url="https://get.helm.sh/helm-${version}-${os}-${arch}.tar.gz"
          local tar="/tmp/helm.tgz"
          download_to "$url" "$tar"
          tar -xzf "$tar" -C /tmp
          install -m 0755 "/tmp/${os}-${arch}/helm" "$bin_path"
          rm -rf "$tar" "/tmp/${os}-${arch}"
          log_info "Installed helm: $("$bin_path" version --short 2>/dev/null || true)"
          ;;
        uninstall)
          remove_if_exists "$bin_path"
          ;;
        *) log_err "Invalid mode '$mode' (binary:helm)"; return 1 ;;
      esac
      ;;

    kubectl)
      bin_path="/usr/local/bin/kubectl"
      case "$mode" in
        install)
          [[ -n "$version" ]] || { log_err "KUBECTL_VERSION is required for kubectl (e.g. v1.30.6)"; return 1; }
          local url="https://dl.k8s.io/release/${version}/bin/${os}/${arch}/kubectl"
          download_to "$url" "/tmp/kubectl"
          install -m 0755 "/tmp/kubectl" "$bin_path"
          rm -f "/tmp/kubectl"
          log_info "Installed kubectl: $("$bin_path" version --client --short 2>/dev/null || true)"
          ;;
        uninstall)
          remove_if_exists "$bin_path"
          ;;
        *) log_err "Invalid mode '$mode' (binary:kubectl)"; return 1 ;;
      esac
      ;;

    *)
      log_err "binary strategy does not yet support app_key '$app_key'"
      return 1
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Strategy: yq_binary
# -----------------------------------------------------------------------------
strategy_yq_binary() {
  local mode="$1"
  local version_var_name="${2:-YQ_VERSION}"

  local version="${!version_var_name:-}"
  local os arch bin_path="/usr/local/bin/yq"
  os="$(detect_os)"
  arch="$(detect_arch)"

  case "$mode" in
    install)
      [[ -n "$version" ]] || { log_err "YQ_VERSION is required (e.g. v4.44.3)"; return 1; }
      # mikefarah/yq uses files like yq_linux_amd64 (no .tar.gz)
      local url="https://github.com/mikefarah/yq/releases/download/${version}/yq_${os}_${arch}"
      download_to "$url" "/tmp/yq"
      install -m 0755 "/tmp/yq" "$bin_path"
      rm -f "/tmp/yq"
      log_info "Installed yq: $("$bin_path" --version 2>/dev/null || true)"
      ;;
    uninstall)
      remove_if_exists "$bin_path"
      ;;
    *) log_err "Invalid mode '$mode' (yq_binary)"; return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Strategy: sops_binary
# -----------------------------------------------------------------------------
strategy_sops_binary() {
  local mode="$1"
  local version_var_name="${2:-SOPS_VERSION}"

  local version="${!version_var_name:-}"
  local os arch bin_path="/usr/local/bin/sops"
  os="$(detect_os)"
  arch="$(detect_arch)"

  case "$mode" in
    install)
      [[ -n "$version" ]] || { log_err "SOPS_VERSION is required (e.g. v3.9.0)"; return 1; }
      # sops uses assets like sops-vX.Y.Z.linux.amd64
      local url="https://github.com/getsops/sops/releases/download/${version}/sops-${version}.${os}.${arch}"
      download_to "$url" "/tmp/sops"
      install -m 0755 "/tmp/sops" "$bin_path"
      rm -f "/tmp/sops"
      log_info "Installed sops: $("$bin_path" --version 2>/dev/null || true)"
      ;;
    uninstall)
      remove_if_exists "$bin_path"
      ;;
    *) log_err "Invalid mode '$mode' (sops_binary)"; return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Strategy: python
# -----------------------------------------------------------------------------
strategy_python() {
  # Conservative: avoid removing python3 itself on uninstall unless explicitly required.
  local mode="$1"
  local _app_key="$2"
  local packages_csv="$3"
  local _version_var_name="${4:-}"

  case "$mode" in
    install)
      apt_install_packages "$packages_csv"
      # Ensure pipx path is usable for interactive sessions.
      if command -v pipx >/dev/null 2>&1; then
        log_info "pipx is installed. Consider ensuring pipx path is set for your users if needed."
      fi
      ;;
    uninstall)
      # Safer default: only remove pipx (and any optional extras you may add later).
      # If packages_csv includes python3, removing it can harm the OS. We therefore filter.
      local pkgs=() filtered=()
      csv_to_array "$packages_csv" pkgs
      for p in "${pkgs[@]}"; do
        case "$p" in
          python3|python3-minimal|python3-venv|python3-pip)
            log_warn "Skipping removal of core Python package '$p' to avoid damaging the base OS."
            ;;
          *) filtered+=("$p") ;;
        esac
      done
      if (( ${#filtered[@]} > 0 )); then
        local tmp_csv
        tmp_csv="$(IFS=','; printf '%s' "${filtered[*]}")"
        apt_remove_packages "$tmp_csv"
      fi
      ;;
    *) log_err "Invalid mode '$mode' (python)"; return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Strategy: nvm (per-user)
# -----------------------------------------------------------------------------
strategy_nvm() {
  # This is intentionally minimal and safe. In many setups, you will want to run
  # this as the target user rather than root, or accept a target username.
  local mode="$1"
  local version_var_name="${2:-NVM_NODE_VERSION}"

  local node_version="${!version_var_name:-lts/*}"
  local target_user
  target_user="$(app_mgr_target_user)"

  case "$mode" in
    install)
      ensure_apt_prereqs "curl,ca-certificates"
      log_info "Installing NVM + Node ($node_version) for user: $target_user"

      run_as_user_if_possible "$target_user" bash -lc "
        set -Eeuo pipefail
        export NVM_DIR=\"\$HOME/.nvm\"
        if [[ ! -d \"\$NVM_DIR\" ]]; then
          curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        fi
        # shellcheck disable=SC1090
        [[ -s \"\$NVM_DIR/nvm.sh\" ]] && . \"\$NVM_DIR/nvm.sh\"
        command -v nvm >/dev/null 2>&1
        nvm install \"$node_version\"
        nvm alias default \"$node_version\"
      "
      ;;

    uninstall)
      log_info "Removing NVM for user: $target_user"
      run_as_user_if_possible "$target_user" bash -lc "
        set -Eeuo pipefail
        rm -rf \"\$HOME/.nvm\" || true
      "
      log_warn "Shell profile cleanup for NVM initialisation lines is not automated."
      ;;

    *) log_err "Invalid mode '$mode' (nvm)"; return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# Optional validation helpers
# -----------------------------------------------------------------------------
strategy_requires_env() {
  # strategy_requires_env <strategy> <app_key> <version_var_name>
  local strategy="$1"
  local app_key="${2:-}"
  local version_var_name="${3:-}"

  case "$strategy" in
    mongodb_repo)
      [[ -n "${MONGODB_SERIES:-}" ]] || { log_err "Missing env var: MONGODB_SERIES (required for mongodb_repo)"; return 1; }
      ;;
    binary)
      case "$app_key" in
        helm)
          [[ -n "${HELM_VERSION:-}" ]] || { log_err "Missing env var: HELM_VERSION (required for helm binary install)"; return 1; }
          ;;
        kubectl)
          [[ -n "${KUBECTL_VERSION:-}" ]] || { log_err "Missing env var: KUBECTL_VERSION (required for kubectl binary install)"; return 1; }
          ;;
      esac
      ;;
    yq_binary)
      [[ -n "${YQ_VERSION:-}" ]] || { log_err "Missing env var: YQ_VERSION (required for yq_binary)"; return 1; }
      ;;
    sops_binary)
      [[ -n "${SOPS_VERSION:-}" ]] || { log_err "Missing env var: SOPS_VERSION (required for sops_binary)"; return 1; }
      ;;
    nvm)
      # Optional: NVM_NODE_VERSION default exists, so no required env var.
      ;;
  esac

  # If version_var_name is explicitly provided for a binary, enforce it if you prefer:
  if [[ -n "$version_var_name" ]]; then
    [[ -n "${!version_var_name:-}" ]] || true
  fi
  return 0
}
