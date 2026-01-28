#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/installers.sh
# Purpose : Installers, repo setup, and strategy dispatch.
#
# Notes
#   - This module contains networked installers (GitHub/Grafana/Mongo/HashiCorp)
#     and non-APT strategies (binary, docker script, nvm, python).
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

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
