#!/usr/bin/env bash
# ==========================================================
# Filename: bootstrap.sh
# Created:  2026-01-31
# Updated:  2026-01-31
# Description:
#   Bootstrap installer for fouchger_homelab.
# Purpose:
#   - Install minimum dependencies (git, dialog)
#   - Clone or update the repo
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
#   - Repo URL and branch can be overridden via REPO_URL and REPO_REF.
#   - This script aims to be safe to re-run.
# ==========================================================
set -Eeuo pipefail

REPO_URL="${REPO_URL:-https://github.com/Fouchger/fouchger_homelab.git}"
REPO_REF="${REPO_REF:-main}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/fouchger_homelab}"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

require_apt() {
  if ! have_cmd apt-get; then
    echo "❌ This bootstrap currently supports Debian/Ubuntu (apt-get required)." >&2
    exit 1
  fi
}

install_deps() {
  require_apt
  local pkgs=(git dialog)
  echo "🧰 Installing dependencies: ${pkgs[*]}"
  sudo apt-get update -y
  sudo apt-get install -y "${pkgs[@]}"
}

clone_or_update() {
  echo "📥 Preparing repo in: $INSTALL_DIR"
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    git -C "$INSTALL_DIR" fetch --all --prune
    git -C "$INSTALL_DIR" checkout "$REPO_REF"
    git -C "$INSTALL_DIR" pull --ff-only
  else
    rm -rf "$INSTALL_DIR"
    git clone --branch "$REPO_REF" "$REPO_URL" "$INSTALL_DIR"
  fi
}

ensure_executables() {
  echo "🔧 Ensuring scripts are executable"
  # Make all .sh executable
  find "$INSTALL_DIR" -type f -name "*.sh" -exec chmod +x {} \;

  # Apply config/executables.list (if present)
  local list_file="$INSTALL_DIR/config/executables.list"
  if [[ -f "$list_file" ]]; then
    while IFS= read -r rel; do
      [[ -z "$rel" ]] && continue
      [[ "$rel" =~ ^# ]] && continue
      local target="$INSTALL_DIR/$rel"
      if [[ -d "$target" ]]; then
        find "$target" -type f -name "*.sh" -exec chmod +x {} \;
      elif [[ -f "$target" ]]; then
        chmod +x "$target"
      fi
    done < "$list_file"
  fi
}

run_homelab() {
  echo "🚀 Launching homelab.sh"
  (cd "$INSTALL_DIR" && ./homelab.sh)
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
