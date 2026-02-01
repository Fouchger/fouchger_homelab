#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: install.sh
# Created:  2026-01-20
# Updated:  2026-01-22
#
# Description:
#   Bootstrap installer for fouchger_homelab. This script is intended to be
#   downloaded and run before the repo exists locally. It will:
#     1) Ensure required tools are installed (git, make) on Debian/Ubuntu/Proxmox
#     2) Clone (or update) the repository into HOMELAB_DIR
#     3) Run an entry target (defaults to: make menu) if available
#
# Usage:
#   bash install.sh
#
# Environment variables:
#   HOMELAB_GIT_URL   Git URL to clone from
#                    Default: https://github.com/Fouchger/fouchger_homelab
#   HOMELAB_DIR       Local directory for the clone
#                    Default: $HOME/Fouchger/fouchger_homelab
#   HOMELAB_ENTRY     Command to run after clone/update
#                    Default: make menu
#   HOMELAB_NO_RUN    If set to 1, do not run HOMELAB_ENTRY (clone only)
#   HOMELAB_INSTALL_PTLOG  If set to 0, skip installing ptlog (Layer 2 capture)
#                    Default: 1
#
# Notes:
#   - This installer currently supports Debian-like systems using apt-get.
#   - GitHub CLI authentication is not handled here; use SSH URLs or HTTPS.
#
# Maintainer: Gert
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

# ------------------------------- Configuration --------------------------------

HOMELAB_GIT_URL="${HOMELAB_GIT_URL:-https://github.com/Fouchger/fouchger_homelab.git}"
HOMELAB_DIR="${HOMELAB_DIR:-$HOME/fouchger_homelab_back_to_basic}"
HOMELAB_BRANCH="${HOMELAB_BRANCH:-back_to_basic}"
HOMELAB_NO_RUN="${HOMELAB_NO_RUN:-0}"

# --------------------------------- Helpers -----------------------------------

log()  { printf '%s\n' "$*"; }
info() { printf 'ℹ️ INFO: %s\n' "$*" >&2; }
warn() { printf '⚠️ Warning: %s\n' "$*" >&2; }
die()  { printf '❌ Error: %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

is_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]]; }

require_sudo() {
  if is_root; then
    return 0
  fi
  if ! have_cmd sudo; then
    die "sudo is required but not installed. Install sudo or run as root."
  fi
  sudo -v
}

on_err() {
  local exit_code=$?
  warn "Install failed (exit code ${exit_code})."
  warn "If this is a permissions issue, ensure your user can run sudo."
  exit "${exit_code}"
}
trap on_err ERR

is_debian_like() {
  # Debian/Ubuntu/Proxmox typically have /etc/debian_version
  [[ -f /etc/debian_version ]] || need_cmd apt-get
}

have_sudo() {
  # Non-interactive safe check: sudo may exist but require a password.
  # We only test presence here; actual commands may still prompt.
  need_cmd sudo
}

# -----------------------------------------------------------------------------
# Function: apt_install
# Description:
#   Installs packages on Debian-like systems.
#   - Prefers nala for better UX and performance.
#   - Automatically installs nala if not present.
#   - Falls back to apt-get if nala cannot be used.
# Notes:
#   - Uses sudo only when not running as root.
# -----------------------------------------------------------------------------
apt_install() {
  local -a pkgs
  local installer
  local -a run_cmd

  pkgs=("$@")

  # No-op if nothing to install
  if [ "${#pkgs[@]}" -eq 0 ]; then
    warn "apt_install called with no packages. Skipping."
    return 0
  fi

  # Decide privilege wrapper
  if is_root; then
    run_cmd=()
  else
    require_sudo
    run_cmd=(sudo)
  fi

  if ! is_debian_like; then
    warn "apt_install called on non-Debian system. Skipping: ${pkgs[*]}"
    return 0
  fi

  # Decide installer
  if have_cmd nala; then
    installer="nala"
  else
    info "nala not found. Installing nala using apt-get."
    "${run_cmd[@]}" apt-get update -y
    if "${run_cmd[@]}" apt-get install -y --no-install-recommends nala; then
      installer="nala"
    else
      warn "Failed to install nala. Falling back to apt-get."
      installer="apt-get"
    fi
  fi

  info "Installing packages using ${installer}: ${pkgs[*]}"

  case "$installer" in
    nala)
      "${run_cmd[@]}" nala update
      "${run_cmd[@]}" nala install -y --no-install-recommends "${pkgs[@]}"
      ;;
    apt-get)
      "${run_cmd[@]}" apt-get update -y
      "${run_cmd[@]}" apt-get install -y --no-install-recommends "${pkgs[@]}"
      ;;
  esac
}

ensure_deps() {
  # Keep this minimal: only what install.sh strictly needs.
  local -a missing=()

  need_cmd git  || missing+=("git")
  need_cmd make || missing+=("make")
  need_cmd curl || missing+=("curl")
  need_cmd script || missing+=("util-linux")
  need_cmd dialog || missing+=("dialog")

  if ((${#missing[@]} > 0)); then
    if is_debian_like; then
      apt_install "${missing[@]}"
    else
      die "Missing required tools: ${missing[*]}. Install them and re-run (non-Debian OS detected)."
    fi
  fi
}

validate_config() {
  [[ -n "${HOMELAB_GIT_URL}" ]] || die "HOMELAB_GIT_URL is empty."
  [[ -n "${HOMELAB_DIR}" ]] || die "HOMELAB_DIR is empty."
  [[ -n "${HOMELAB_BRANCH}" ]] || die "HOMELAB_BRANCH is empty."

  # Avoid surprising relative paths.
  if [[ "${HOMELAB_DIR}" != /* ]]; then
    die "HOMELAB_DIR must be an absolute path. Current value: ${HOMELAB_DIR}"
  fi
}

clone_or_update() {
  if [[ -d "${HOMELAB_DIR}/.git" ]]; then
    info "🔄 Updating existing repo at ${HOMELAB_DIR}"
    git -C "$HOMELAB_DIR" fetch --all --prune
    git -C "$HOMELAB_DIR" checkout "$HOMELAB_BRANCH"
    git -C "$HOMELAB_DIR" pull --ff-only || true
  else
    info "📥 Cloning repo to ${HOMELAB_DIR}"
    git clone --branch "$HOMELAB_BRANCH" "$HOMELAB_GIT_URL" "$HOMELAB_DIR"
  fi
}

ensure_executables() {
  info "🔧 Ensuring scripts are executable"

  # Make all .sh executable, excluding archived legacy code.
  find "$HOMELAB_DIR" \
    -path "$HOMELAB_DIR/archieve" -prune -o \
    -type f -name "*.sh" -exec chmod +x {} \;

  # Apply config/executables.list (if present)
  local list_file="$HOMELAB_DIR/config/executables.list"
  if [[ -f "$list_file" ]]; then
    while IFS= read -r rel; do
      [[ -z "$rel" ]] && continue
      [[ "$rel" =~ ^# ]] && continue
      local target="$HOMELAB_DIR/$rel"
      if [[ -d "$target" ]]; then
        find "$target" \
          -path "$HOMELAB_DIR/archieve" -prune -o \
          -type f -name "*.sh" -exec chmod +x {} \;
      elif [[ -f "$target" ]]; then
        chmod +x "$target"
      fi
    done < "$list_file"
  fi
}

run_homelab() {
  info "🚀 Launching homelab.sh"
  (cd "$HOMELAB_DIR" && ./homelab.sh)
}