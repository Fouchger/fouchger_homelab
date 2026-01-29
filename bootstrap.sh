#!/usr/bin/env bash
# ==========================================================
# bootstrap.sh
# Created: 29/01/2026
# Updated: 29/01/2026
# Purpose: Minimal bootstrap to download repo and run menu.
# Installs only dependencies required for: cloning + dialog UI.
# ==========================================================
set -euo pipefail

REPO_URL_DEFAULT="https://github.com/YOURORG/homelab.git"
BRANCH_DEFAULT="main"
INSTALL_DIR_DEFAULT="${HOME}/homelab"

REPO_URL="${REPO_URL:-$REPO_URL_DEFAULT}"
BRANCH="${BRANCH:-$BRANCH_DEFAULT}"
INSTALL_DIR="${INSTALL_DIR:-$INSTALL_DIR_DEFAULT}"

log() { printf "%s\n" "$*" >&2; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

detect_pkg_mgr() {
  if need_cmd apt-get; then echo "apt"; return; fi
  if need_cmd dnf; then echo "dnf"; return; fi
  if need_cmd yum; then echo "yum"; return; fi
  if need_cmd pacman; then echo "pacman"; return; fi
  if need_cmd zypper; then echo "zypper"; return; fi
  echo "unknown"
}

install_minimum_deps() {
  local pmgr
  pmgr="$(detect_pkg_mgr)"

  log "Installing minimum dependencies (git, dialog, ca-certs)..."
  case "$pmgr" in
    apt)
      sudo apt-get update -y
      sudo apt-get install -y git dialog ca-certificates
      ;;
    dnf)
      sudo dnf install -y git dialog ca-certificates
      ;;
    yum)
      sudo yum install -y git dialog ca-certificates
      ;;
    pacman)
      sudo pacman -Sy --noconfirm git dialog ca-certificates
      ;;
    zypper)
      sudo zypper --non-interactive install git dialog ca-certificates
      ;;
    *)
      log "Unsupported OS/package manager. Install 'git' and 'dialog' manually, then re-run."
      exit 1
      ;;
  esac
}

main() {
  if ! need_cmd git || ! need_cmd dialog; then
    install_minimum_deps
  fi

  mkdir -p "$(dirname "$INSTALL_DIR")"

  if [ -d "$INSTALL_DIR/.git" ]; then
    log "Repo already present at $INSTALL_DIR, updating..."
    git -C "$INSTALL_DIR" fetch --all --prune
    git -C "$INSTALL_DIR" checkout "$BRANCH"
    git -C "$INSTALL_DIR" pull --ff-only
  else
    log "Cloning repo to $INSTALL_DIR..."
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR"
  fi

  # Ensure execution permissions for required scripts
  # The repo code handles broader chmod too, but this ensures we can start.
  chmod +x "$INSTALL_DIR/homelab.sh" || true
  chmod +x "$INSTALL_DIR/bin/menu.sh" || true

  exec "$INSTALL_DIR/homelab.sh"
}

main "$@"
