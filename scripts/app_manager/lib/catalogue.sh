#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/catalogue.sh
# Purpose : Application catalogue + helpers
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# Catalogue format:
#   HEADING|<text>
#   BLANK|<text>
#   APP|<key>|<label>|<default:ON/OFF>|<packages_csv>|<description>|<strategy>|<version_var>
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

catalogue_all_app_keys() {
  local row type key
  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key _rest <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    validate_key "${key}" || continue
    printf '%s\n' "${key}"
  done
}

catalogue_default_selected_keys() {
  local row type key _label def
  for row in "${APP_CATALOGUE[@]}"; do
    IFS='|' read -r type key _label def _rest <<<"${row}"
    [[ "${type}" == "APP" ]] || continue
    validate_key "${key}" || continue
    [[ "${def}" == "ON" ]] && printf '%s\n' "${key}"
  done
}

catalogue_row_by_key() {
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
