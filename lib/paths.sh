#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/paths.sh
# Created: 2026-01-21
# Updated: 2026-02-01
# Description:
#   Repository path resolution helpers for fouchger_homelab-back_to_basic.
#
# Usage:
#   source "${ROOT_DIR}/lib/paths.sh"      # if ROOT_DIR already known
#   OR
#   source "lib/paths.sh"                  # resolves ROOT_DIR on source
#
# Notes:
#   - Safe to source early. Does not change caller shell options.
#   - Resolution order:
#       1) Honour existing ROOT_DIR if it looks valid.
#       2) Use git (if available) for accurate worktree/submodule support.
#       3) Walk up from PWD until .root_marker is found.
#   - Exports ROOT_DIR and also REPO_ROOT as a compatibility alias.
# -----------------------------------------------------------------------------

# Guardrail: prevent double-sourcing.
if [[ -n "${_HOMELAB_PATHS_SOURCED:-}" ]]; then
  return 0
fi
readonly _HOMELAB_PATHS_SOURCED="1"

_homelab_paths_error() { echo "Error: $*" >&2; }

_homelab_root_marker() {
  echo ".root_marker"
}

_find_root_by_marker() {
  local dir="${1:-$PWD}"
  local marker
  marker="$(_homelab_root_marker)"

  while :; do
    if [[ -e "${dir%/}/$marker" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    [[ "$dir" == "/" ]] && break
    dir="$(dirname -- "$dir")"
  done

  return 1
}

resolve_root_dir() {
  local marker
  marker="$(_homelab_root_marker)"

  # -1) Allow an explicit repo override (useful for installed wrappers).
  if [[ -n "${HOMELAB_REPO_ROOT:-${B2B_REPO_ROOT:-}}" ]]; then
    local override
    override="${HOMELAB_REPO_ROOT:-${B2B_REPO_ROOT:-}}"
    if [[ -d "$override" && -e "${override%/}/$marker" ]]; then
      ROOT_DIR="$override"
      export ROOT_DIR
      printf '%s' "$ROOT_DIR"
      return 0
    fi
  fi

  # 0) Honour existing ROOT_DIR only if it looks valid.
  if [[ -n "${ROOT_DIR:-}" && -d "${ROOT_DIR:-}" && -e "${ROOT_DIR%/}/$marker" ]]; then
    printf '%s' "$ROOT_DIR"
    return 0
  fi

  # 1) Preferred: ask Git.
  if command -v git >/dev/null 2>&1; then
    local git_root
    if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
      ROOT_DIR="$git_root"
      export ROOT_DIR
      printf '%s' "$ROOT_DIR"
      return 0
    fi
  fi

  # 2) Fallback: marker walk.
  local walked
  if walked="$(_find_root_by_marker "${PWD}")"; then
    ROOT_DIR="$walked"
    export ROOT_DIR
    printf '%s' "$ROOT_DIR"
    return 0
  fi

  _homelab_paths_error "not inside a recognised repository (no git root and no $marker found)"
  return 1
}

# Resolve immediately on source.
ROOT_DIR="$(resolve_root_dir)" || return 1
export ROOT_DIR

# Compatibility alias.
REPO_ROOT="$ROOT_DIR"
export REPO_ROOT
