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

HOMELAB_GIT_URL="${HOMELAB_GIT_URL:-https://github.com/Fouchger/fouchger_homelab}"
HOMELAB_DIR="${HOMELAB_DIR:-$HOME/Fouchger/fouchger_homelab}"
HOMELAB_ENTRY="${HOMELAB_ENTRY:-make menu}"
HOMELAB_NO_RUN="${HOMELAB_NO_RUN:-0}"

# --------------------------------- Helpers -----------------------------------

log()  { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

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

apt_install() {
  local -a pkgs=("$@")

  need_cmd apt-get || die "apt-get not found. This installer currently supports Debian-like systems only."
  have_sudo || die "sudo not found. Install sudo or run as a user with package install rights."

  log "Installing dependencies via apt-get: ${pkgs[*]}"
  sudo apt-get update -y
  sudo apt-get install -y "${pkgs[@]}"
}

ensure_deps() {
  # Keep this minimal: only what install.sh strictly needs.
  local -a missing=()

  need_cmd git  || missing+=("git")
  need_cmd make || missing+=("make")

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

  # Avoid surprising relative paths.
  if [[ "${HOMELAB_DIR}" != /* ]]; then
    die "HOMELAB_DIR must be an absolute path. Current value: ${HOMELAB_DIR}"
  fi
}

clone_or_update() {
  mkdir -p "$(dirname "${HOMELAB_DIR}")"

  if [[ -d "${HOMELAB_DIR}/.git" ]]; then
    log "Updating existing repo in ${HOMELAB_DIR}"
    if ! git -C "${HOMELAB_DIR}" pull --ff-only; then
      warn "Your local repo can't fast-forward."
      warn "Options:"
      warn "  1) Commit or stash your changes, then re-run"
      warn "  2) Or reset hard to remote if you know what you're doing"
      return 1
    fi
  else
    log "Cloning repo to ${HOMELAB_DIR}"
    git clone "${HOMELAB_GIT_URL}" "${HOMELAB_DIR}"
  fi
}

post_clone_fixups() {
  cd "${HOMELAB_DIR}"

  # Ensure scripts are executable (prevents 'Permission denied' during bootstrap).
  if [[ -f "scripts/core/make-executable.sh" ]]; then
    bash "scripts/core/make-executable.sh"
  else
    # Repo may be mid-build; keep this safe and non-fatal.
    warn "scripts/core/make-executable.sh not found. Applying fallback chmod for scripts/*.sh (if present)."
    if [[ -d "scripts" ]]; then
      find scripts -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    fi
  fi
}

run_entry() {
  cd "${HOMELAB_DIR}"

  if [[ "${HOMELAB_NO_RUN}" == "1" ]]; then
    log "HOMELAB_NO_RUN=1 set. Clone/update complete."
    log "Next steps:"
    log "  cd \"${HOMELAB_DIR}\""
    log "  ${HOMELAB_ENTRY}"
    return 0
  fi

  # Prefer Makefile if the default entry uses make.
  if [[ "${HOMELAB_ENTRY}" == make* ]]; then
    [[ -f "Makefile" ]] || die "Makefile not found in ${HOMELAB_DIR}. Is this the right repo/branch?"
  fi

  log "Running: ${HOMELAB_ENTRY}"
  # Intentionally allow word-splitting for command-style entry.
  # shellcheck disable=SC2086
  ${HOMELAB_ENTRY}
}

# ---------------------------------- Main -------------------------------------

main() {
  validate_config
  ensure_deps
  clone_or_update
  post_clone_fixups
  run_entry
}

main "$@"
