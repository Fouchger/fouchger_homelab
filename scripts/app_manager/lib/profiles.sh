#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/profiles.sh
# Created: 28/01/2026
# Updated: 28/01/2026
# Description: 
#
# Notes
#   - 
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

if [[ -z "${REPO_ROOT:-}" ]]; then
  REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi

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
