#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/core.sh
# Created: 2026-01-18
# Description: Core helpers shared across scripts (deps, sudo, OS checks).
# Usage:
#   source "${REPO_ROOT}/lib/paths.sh"
#   source "${REPO_ROOT}/lib/logging.sh"
#   source "${REPO_ROOT}/lib/core.sh"
# Developer notes:
#   - Keep bash 4+ compatible.
#   - Avoid non-POSIX flags.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

# Checks whether a command exists, and logging or treating it as an error.
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    error "Missing required command: $1"
    return 1
  }
}

# Checks whether a command exists, but without logging or treating it as an error.
have_cmd() { command -v "$1" >/dev/null 2>&1; }

# Determines whether the current process is running as root. Sudo not required
is_root() { [ "${EUID:-$(id -u)}" -eq 0 ]; }

# Ensures the script can perform privileged actions either by already being root or by having working sudo.
require_sudo() {
  if is_root; then
    return 0
  fi
  if ! have_cmd sudo; then
    error "sudo is required but not installed. Install sudo or run as root."
    return 1
  fi
  sudo -v
}

# Returns the OS identifier from /etc/os-release.
get_os_id() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    printf '%s' "${ID:-unknown}"
  else
    printf '%s' "unknown"
  fi
}

# Returns the “OS family” identifier(s) from /etc/os-release.
get_os_like() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    printf '%s' "${ID_LIKE:-}"
  else
    printf '%s' ""
  fi
}

# Decides whether the current OS should be treated as Debian-family for package management purposes.
is_debian_like() {
  local id like
  id="$(get_os_id)"; like="$(get_os_like)"
  case "$id" in debian|ubuntu|raspbian) return 0 ;; esac
  printf '%s' "$like" | grep -qiE '(debian|ubuntu)' && return 0
  return 1
}

# Installs packages using apt-get, but only on Debian-like systems.
# apt_install() {
#   local pkgs
#   pkgs=("$@")
#   require_sudo
#   if ! is_debian_like; then
#     warn "apt_install called on non-Debian system. Skipping: ${pkgs[*]}"
#     return 0
#   fi
#   info "Installing packages: ${pkgs[*]}"
#   sudo apt-get update
#   sudo apt-get install -y --no-install-recommends "${pkgs[@]}"
# }

# -----------------------------------------------------------------------------
# Function: apt_install
# Description:
#   Installs packages on Debian-like systems.
#   - Prefers nala for better UX and performance.
#   - Automatically installs nala if not present.
#   - Falls back to apt-get if nala cannot be used.
# Notes:
#   - Requires lib/logging.sh for info/warn/error helpers.
#   - Requires lib/core.sh helpers: require_sudo, have_cmd, is_debian_like.
# -----------------------------------------------------------------------------
apt_install() {
  local pkgs installer

  pkgs=("$@")

  # No-op if nothing to install
  if [ "${#pkgs[@]}" -eq 0 ]; then
    warn "apt_install called with no packages. Skipping."
    return 0
  fi

  require_sudo

  if ! is_debian_like; then
    warn "apt_install called on non-Debian system. Skipping: ${pkgs[*]}"
    return 0
  fi

  # Decide installer
  if have_cmd nala; then
    installer="nala"
  else
    info "nala not found. Installing nala using apt-get."
    sudo apt-get update -y
    if sudo apt-get install -y --no-install-recommends nala; then
      installer="nala"
    else
      warn "Failed to install nala. Falling back to apt-get."
      installer="apt-get"
    fi
  fi

  info "Installing packages using ${installer}: ${pkgs[*]}"

  case "$installer" in
    nala)
      sudo nala update
      sudo nala install -y --no-install-recommends "${pkgs[@]}"
      ;;
    apt-get)
      sudo apt-get update -y
      sudo apt-get install -y --no-install-recommends "${pkgs[@]}"
      ;;
  esac
}

