#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/paths.sh
# Created: 2026-01-21
# Updated: 2026-02-03
# Description:
#   Repository path resolution helpers and standard directory layout.
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
#   - Defines a repository-local state layout under $ROOT_DIR/state.
#     This is the single place for:
#       - user-set settings (config)
#       - secrets (not committed)
#       - logs
#       - command output artifacts
#
#   Directory defaults (all can be overridden via env vars):
#     HOMELAB_STATE_DIR        $ROOT_DIR/state
#     HOMELAB_CONFIG_DIR       $HOMELAB_STATE_DIR/config
#     HOMELAB_CONFIG_FILE      $HOMELAB_CONFIG_DIR/homelab.conf
#     HOMELAB_SECRETS_DIR      $HOMELAB_STATE_DIR/secrets
#     HOMELAB_LOG_DIR          $HOMELAB_STATE_DIR/logs
#     HOMELAB_OUTPUT_DIR       $HOMELAB_STATE_DIR/output
#     HOMELAB_CACHE_DIR        $HOMELAB_STATE_DIR/cache
#     HOMELAB_TMP_DIR          $HOMELAB_STATE_DIR/tmp
#
#   Call homelab_paths_init to create these folders (safe to call repeatedly).
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

# -----------------------------------------------------------------------------
# Standard repo-local state layout
# -----------------------------------------------------------------------------
# The project keeps runtime state (settings, secrets, logs, command outputs)
# under a single repo-local folder by default:
#   $ROOT_DIR/state
#
# This folder should never be committed to Git. Ensure your .gitignore includes:
#   /state/
#
# You can override any of these paths via environment variables.

homelab_paths__ensure_dir() {
  local dir="$1"
  [[ -z "$dir" ]] && return 1
  mkdir -p "$dir" 2>/dev/null || return 1
}

homelab_paths_init() {
  # Runtime state root (settings, secrets, logs, output).
  HOMELAB_STATE_DIR="${HOMELAB_STATE_DIR:-${ROOT_DIR%/}/state}"

  # Subfolders.
  HOMELAB_CONFIG_DIR="${HOMELAB_CONFIG_DIR:-${HOMELAB_STATE_DIR%/}/config}"
  HOMELAB_SECRETS_DIR="${HOMELAB_SECRETS_DIR:-${HOMELAB_STATE_DIR%/}/secrets}"
  HOMELAB_LOG_DIR="${HOMELAB_LOG_DIR:-${HOMELAB_STATE_DIR%/}/logs}"
  HOMELAB_OUTPUT_DIR="${HOMELAB_OUTPUT_DIR:-${HOMELAB_STATE_DIR%/}/output}"
  HOMELAB_CACHE_DIR="${HOMELAB_CACHE_DIR:-${HOMELAB_STATE_DIR%/}/cache}"
  HOMELAB_TMP_DIR="${HOMELAB_TMP_DIR:-${HOMELAB_STATE_DIR%/}/tmp}"

  # Canonical config file location inside state.
  HOMELAB_STATE_CONFIG_FILE="${HOMELAB_STATE_CONFIG_FILE:-${HOMELAB_CONFIG_DIR%/}/homelab.conf}"

  export HOMELAB_STATE_DIR
  export HOMELAB_CONFIG_DIR
  export HOMELAB_SECRETS_DIR
  export HOMELAB_LOG_DIR
  export HOMELAB_OUTPUT_DIR
  export HOMELAB_CACHE_DIR
  export HOMELAB_TMP_DIR
  export HOMELAB_STATE_CONFIG_FILE

  # Create folders best-effort. If the repo is read-only, the caller can
  # choose to override HOMELAB_STATE_DIR to a writable location.
  homelab_paths__ensure_dir "$HOMELAB_STATE_DIR" || true
  homelab_paths__ensure_dir "$HOMELAB_CONFIG_DIR" || true
  homelab_paths__ensure_dir "$HOMELAB_SECRETS_DIR" || true
  homelab_paths__ensure_dir "$HOMELAB_LOG_DIR" || true
  homelab_paths__ensure_dir "$HOMELAB_OUTPUT_DIR" || true
  homelab_paths__ensure_dir "$HOMELAB_CACHE_DIR" || true
  homelab_paths__ensure_dir "$HOMELAB_TMP_DIR" || true
}

# Initialise standard paths immediately so later libraries can rely on them.
homelab_paths_init

