#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: install.sh
# Created:  2026-01-31
# Updated:  2026-01-31
#
# Description:
#   Remote installer for fouchger_homelab. Designed to be run via curl before the
#   repository exists locally.
#
# Purpose:
#   - Install only the minimum prerequisites required to fetch the repository
#     (git, curl, ca-certificates)
#   - Clone or update the repository into HOMELAB_DIR
#   - Delegate all dependency installation, permission setting, and runtime
#     handoff to bootstrap.sh (single source of truth)
#
# Usage:
#   bash -c "$(curl -fsSL <raw install.sh url>)"
#   or
#   ./install.sh
#
# Environment variables:
#   HOMELAB_GIT_URL   Git URL to clone from
#                    Default: https://github.com/Fouchger/fouchger_homelab.git
#   HOMELAB_DIR       Local directory for the clone
#                    Default: $HOME/fouchger_homelab
#   HOMELAB_BRANCH    Branch to checkout
#                    Default: main
#
# Prerequisites:
#   - Debian/Ubuntu/Proxmox with apt
#   - Sudo access for package installation
#
# Notes:
#   - This script must never print secrets. It does not read secrets.
# -----------------------------------------------------------------------------

set -Eeuo pipefail

HOMELAB_GIT_URL="${HOMELAB_GIT_URL:-https://github.com/Fouchger/fouchger_homelab.git}"
HOMELAB_DIR="${HOMELAB_DIR:-$HOME/fouchger_homelab}"
HOMELAB_BRANCH="${HOMELAB_BRANCH:-main}"

_die() { echo "🛑 $*" >&2; exit 1; }
_have() { command -v "$1" >/dev/null 2>&1; }

_need_sudo() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    _have sudo || _die "sudo is required but not installed"
    echo sudo
  fi
}

_require_apt() {
  _have apt-get || _die "This installer currently supports Debian/Ubuntu/Proxmox (apt)."
}

_install_prereqs() {
  _require_apt
  local sudo_cmd
  sudo_cmd="$(_need_sudo || true)"

  echo "📦 Installing prerequisites (git, curl, ca-certificates)…"
  $sudo_cmd apt-get update -y
  $sudo_cmd apt-get install -y git curl ca-certificates
}

_clone_or_update() {
  if [[ -d "${HOMELAB_DIR}/.git" ]]; then
    echo "🔄 Updating existing repo at ${HOMELAB_DIR}"
    git -C "$HOMELAB_DIR" fetch --all --prune
    git -C "$HOMELAB_DIR" checkout "$HOMELAB_BRANCH"
    git -C "$HOMELAB_DIR" pull --ff-only || true
  else
    echo "📥 Cloning repo to ${HOMELAB_DIR}"
    git clone --branch "$HOMELAB_BRANCH" "$HOMELAB_GIT_URL" "$HOMELAB_DIR"
  fi
}

_handoff_to_bootstrap() {
  cd "$HOMELAB_DIR"
  [[ -x "./bootstrap.sh" ]] || _die "bootstrap.sh not found or not executable in ${HOMELAB_DIR}"

  echo "🚀 Delegating to bootstrap.sh"
  # Single source of truth: bootstrap.sh handles deps, perms, and handoff.
  REPO_URL="$HOMELAB_GIT_URL" REPO_REF="$HOMELAB_BRANCH" INSTALL_DIR="$HOMELAB_DIR" SKIP_CLONE=1 ./bootstrap.sh
}

main() {
  _install_prereqs
  _clone_or_update
  _handoff_to_bootstrap
}

main "$@"
