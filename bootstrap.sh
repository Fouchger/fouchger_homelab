#!/usr/bin/env bash
# ==============================================================================
# File: bootstrap.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Bootstrapper for host prerequisites and repo setup.
# Purpose: Ensures required baseline packages and permissions exist to run homelab.
# Usage:
#   ./bootstrap.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# ==========================================================
# Filename: bootstrap.sh
# Created:  2026-01-31
# Updated:  2026-01-31
# Description:
#   Bootstrap installer for fouchger_homelab.
# Purpose:
#   - Install minimum dependencies required to run the homelab runtime
#     (git, dialog, curl, ca-certificates)
#   - Clone or update the repo (unless SKIP_CLONE=1)
#   - Ensure required scripts are executable
#   - Hand off to homelab.sh
# Usage:
#   curl -fsSL <raw bootstrap.sh url> | bash
#   or
#   ./bootstrap.sh
# Prerequisites:
#   - Debian/Ubuntu with apt
#   - Sudo access for package installation
# Notes:
#   - Repo URL and branch can be overridden via HOMELAB_GIT_URL and HOMELAB_BRANCH.
#   - If SKIP_CLONE=1, this script assumes HOMELAB_DIR already contains the repo.
#   - This script aims to be safe to re-run.
# ==========================================================
set -Eeuo pipefail

HOMELAB_GIT_URL="${HOMELAB_GIT_URL:-https://github.com/Fouchger/fouchger_homelab.git}"
HOMELAB_DIR="${HOMELAB_DIR:-$HOME/fouchger_homelab}"
HOMELAB_BRANCH="${HOMELAB_BRANCH:-rewrite}"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

require_apt() {
  if ! have_cmd apt-get; then
    echo "❌ This bootstrap currently supports Debian/Ubuntu (apt-get required)." >&2
    exit 1
  fi
}

need_sudo() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    if ! have_cmd sudo; then
      echo "❌ sudo is required but not installed." >&2
      exit 1
    fi
    echo sudo
  fi
}

install_deps() {
  require_apt
  local sudo_cmd
  sudo_cmd="$(need_sudo || true)"

  local pkgs=(git dialog curl ca-certificates)
  echo "🧰 Installing dependencies: ${pkgs[*]}"
  $sudo_cmd apt-get update -y
  $sudo_cmd apt-get install -y "${pkgs[@]}"
}

clone_or_update() {
  if [[ "${SKIP_CLONE:-1}" == "1" ]]; then
    echo "⏭️  SKIP_CLONE=1 set; using existing repo at: $HOMELAB_DIR"
    return 0
  fi

  echo "📥 Preparing repo in: $HOMELAB_DIR"
  if [[ -d "$HOMELAB_DIR/.git" ]]; then
    git -C "$HOMELAB_DIR" fetch --all --prune
    git -C "$HOMELAB_DIR" checkout "$HOMELAB_BRANCH"
    git -C "$HOMELAB_DIR" pull --ff-only
  else
    rm -rf "$HOMELAB_DIR"
    git clone --branch "$HOMELAB_BRANCH" "$HOMELAB_GIT_URL" "$HOMELAB_DIR"
  fi
}

ensure_executables() {
  echo "🔧 Ensuring scripts are executable"
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
  echo "🚀 Launching homelab.sh"
  (cd "$HOMELAB_DIR" && ./homelab.sh)
}

main() {
  if ! have_cmd git || ! have_cmd dialog; then
    install_deps
  fi
  clone_or_update
  ensure_executables
  run_homelab
}

main "$@"
