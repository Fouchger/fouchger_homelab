#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/profiles.sh
# Purpose : Profile definitions (keys + version pins)
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

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
