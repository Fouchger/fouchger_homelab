#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/paths.sh
# Created: 2026-01-21
# Updated: 2026-01-24
# Description: Standard path resolution helpers for fouchger_homelab.
# Usage:
#   source "${REPO_ROOT}/lib/paths.sh"   # if REPO_ROOT already known
#   OR
#   source "lib/paths.sh"               # will resolve REPO_ROOT on source
#
# Developer notes:
#   - This file is safe to source early. It must not change caller shell options
#     (no 'set -e/-u/-o pipefail' here).
#   - REPO_ROOT resolution principle:
#       1) Use Git top-level when git is available.
#       2) Otherwise resolve by walking up for a persistent marker file.
#       3) Create the marker file on first successful resolution and add to
#          .gitignore to support runs where git is not installed.
#   - Marker file: .homelab_repo_root (at repo root).
# -----------------------------------------------------------------------------
echo "lib/paths.sh"
# Guardrail: prevent double-sourcing.
if [[ -n "${_HOMELAB_PATHS_SOURCED:-}" ]]; then
  return 0
fi
readonly _HOMELAB_PATHS_SOURCED="1"

_homelab_paths_error() { echo "Error: $*" >&2; }
_homelab_paths_warn()  { echo "Warning: $*" >&2; }

_homelab_ensure_repo_marker() {
  local root="$1"
  local marker="$2"
  local marker_path ignore_path

  marker_path="${root%/}/$marker"
  ignore_path="${root%/}/.gitignore"

  if [[ ! -f "$marker_path" ]]; then
    : >"$marker_path" 2>/dev/null || {
      _homelab_paths_warn "unable to create repo marker at $marker_path"
      return 0
    }
  fi

  # Update .gitignore in a safe, idempotent way.
  if [[ -f "$ignore_path" ]]; then
    if ! grep -qxF "$marker" "$ignore_path" 2>/dev/null; then
      printf '%s\n' "$marker" >>"$ignore_path" 2>/dev/null || _homelab_paths_warn "unable to update $ignore_path"
    fi
  else
    printf '%s\n' "$marker" >"$ignore_path" 2>/dev/null || _homelab_paths_warn "unable to create $ignore_path"
  fi
}

_find_repo_root_by_marker() {
  local dir="$PWD"
  local marker=".homelab_repo_root"

  while :; do
    if [[ -f "${dir%/}/$marker" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    [[ "$dir" == "/" ]] && break
    dir="${dir%/*}"
    [[ -z "$dir" ]] && dir="/"
  done

  return 1
}

resolve_repo_root() {
  local marker=".homelab_repo_root"
  local repo_root=""

  # 0) Honour existing REPO_ROOT only if it looks valid.
  if [[ -n "${REPO_ROOT:-}" && -d "${REPO_ROOT:-}" ]]; then
    # If marker exists, we trust it. If git exists, we can also trust .git/.gitfile layouts via git.
    if [[ -f "${REPO_ROOT%/}/$marker" ]]; then
      printf '%s' "$REPO_ROOT"
      return 0
    fi
  fi

  # 1) Preferred: ask Git (handles worktrees/submodules properly).
  if command -v git >/dev/null 2>&1; then
    if repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
      REPO_ROOT="$repo_root"
      export REPO_ROOT
      _homelab_ensure_repo_marker "$REPO_ROOT" "$marker"
      printf '%s' "$REPO_ROOT"
      return 0
    fi
  fi

  # 2) Fallback: marker walk.
  if repo_root="$(_find_repo_root_by_marker)"; then
    REPO_ROOT="$repo_root"
    export REPO_ROOT
    printf '%s' "$REPO_ROOT"
    return 0
  fi

  _homelab_paths_error "not inside a recognised repository (no git root and no $marker found)"
  return 1
}

# Resolve immediately on source, as your current file expects.
# Caller can override by exporting REPO_ROOT beforehand.
REPO_ROOT="$(resolve_repo_root)" || return 1
export REPO_ROOT

STATE_DIR_DEFAULT="${STATE_DIR_DEFAULT:-$HOME/.config/fouchger_homelab}"
LOG_DIR_DEFAULT="${LOG_DIR_DEFAULT:-$STATE_DIR_DEFAULT/logs}"
STATE_DIR="${STATE_DIR:-$STATE_DIR_DEFAULT/state}"
BIN_DIR="${BIN_DIR:-$STATE_DIR_DEFAULT/bin}"

APPM_DIR="${STATE_DIR_DEFAULT}/app_manager"
ENV_BACKUP_DIR="${APPM_DIR}/.backups"

MARKER_DIR="${STATE_DIR}/markers"

ensure_dirs() {
  mkdir -p \
    "$LOG_DIR_DEFAULT" \
    "$STATE_DIR_DEFAULT" \
    "$STATE_DIR" \
    "$BIN_DIR" \
    "$APPM_DIR" \
    "$ENV_BACKUP_DIR" \
    "$MARKER_DIR"
}

# Convenience: do not fail hard if filesystem is constrained.
ensure_dirs >/dev/null 2>&1 || true
