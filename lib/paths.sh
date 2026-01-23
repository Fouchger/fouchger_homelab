#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/paths.sh
# Created: 2026-01-21
# Description: Standard path resolution helpers for fouchger_homelab.
# Usage:
#   source "${REPO_ROOT}/lib/paths.sh"
# Developer notes:
#   - Keep this file dependency-free so every script can source it early.
# -----------------------------------------------------------------------------

set -Eeuo pipefail

find_repo_root() {
  local dir
  dir="$(pwd)"

  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  return 1
}

if ! REPO_ROOT="$(find_repo_root)"; then
  echo "Error: not inside a Git repository (.git not found)" >&2
  exit 1
fi

export REPO_ROOT

STATE_DIR_DEFAULT="${STATE_DIR_DEFAULT:-$HOME/.config/fouchger_homelab}"
LOG_DIR_DEFAULT="${LOG_DIR_DEFAULT:-$STATE_DIR_DEFAULT/logs}"
STATE_DIR="${STATE_DIR:-$STATE_DIR_DEFAULT/state}"
BIN_DIR="${BIN_DIR:-$STATE_DIR_DEFAULT/bin}"

APPM_DIR="${STATE_DIR_DEFAULT}/app_manager"
ENV_BACKUP_DIR="${APPM_DIR}/.backups"

MARKER_DIR="${STATE_DIR}/markers"

# Creates default directories used by the project.
ensure_dirs() {
  mkdir -p "$LOG_DIR_DEFAULT" "$STATE_DIR_DEFAULT" "$STATE_DIR" "$BIN_DIR" \
  "$APPM_DIR" "$ENV_BACKUP_DIR" "$MARKER_DIR"
}

ensure_dirs