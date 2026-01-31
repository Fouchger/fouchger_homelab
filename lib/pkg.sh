#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/pkg.sh
# Created: 2026-01-31
# Updated: 2026-02-01
# Description: Package manager wrapper for Debian/Ubuntu.
# Purpose: Prefer nala when available, fallback to apt-get.
# Usage:
#   source "${ROOT_DIR}/lib/pkg.sh"
#   pkg_update
#   pkg_install curl jq
#   pkg_remove docker.io
# Notes:
#   - Non-interactive by default (safe for automation).
#   - Uses sudo when not running as root.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

pkg__have() { command -v "$1" >/dev/null 2>&1; }

pkg__sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    echo ""
  elif pkg__have sudo; then
    echo "sudo"
  else
    echo ""
  fi
}

pkg__backend() {
  if pkg__have nala; then
    echo "nala"
  else
    echo "apt-get"
  fi
}

pkg_update() {
  local sudo_cmd backend
  sudo_cmd="$(pkg__sudo)"
  backend="$(pkg__backend)"

  if [[ "${backend}" == "nala" ]]; then
    # Note: sudo cannot run a command prefixed with VAR=value (it treats VAR=value
    # as the command). Use env so this works both with and without sudo.
    ${sudo_cmd} env DEBIAN_FRONTEND=noninteractive nala update
  else
    ${sudo_cmd} env DEBIAN_FRONTEND=noninteractive apt-get update
  fi
}

pkg_install() {
  local sudo_cmd backend
  sudo_cmd="$(pkg__sudo)"
  backend="$(pkg__backend)"

  if [[ "$#" -eq 0 ]]; then
    return 0
  fi

  if [[ "${backend}" == "nala" ]]; then
    ${sudo_cmd} env DEBIAN_FRONTEND=noninteractive nala install -y "$@"
  else
    ${sudo_cmd} env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
  fi
}

pkg_remove() {
  local sudo_cmd backend
  sudo_cmd="$(pkg__sudo)"
  backend="$(pkg__backend)"

  if [[ "$#" -eq 0 ]]; then
    return 0
  fi

  if [[ "${backend}" == "nala" ]]; then
    ${sudo_cmd} env DEBIAN_FRONTEND=noninteractive nala remove -y "$@"
  else
    ${sudo_cmd} env DEBIAN_FRONTEND=noninteractive apt-get remove -y "$@"
  fi
}

# This library is intended to be sourced. Do not execute actions on load.