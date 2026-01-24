#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/common.sh
# Created: 2026-01-24
# Description:
#   Common utilities for fouchger_homelab scripts.
#
#   Key features:
#   - Consistent REPO_ROOT resolution from any subfolder and any executable.
#   - Uses Git root when available, otherwise uses a persistent marker file.
#   - Creates the marker on first successful resolution and adds it to .gitignore.
#   - Guardrails: strict mode friendly, no global side effects beyond exported vars.
#
# Usage:
#   source "$REPO_ROOT/lib/common.sh"  (after resolve_repo_root) OR
#   source "path/to/lib/common.sh"; resolve_repo_root
#
# Developer notes:
#   - Error handling prefers UI helpers (ui_error/ui_warn/ui_info) when present.
#   - Marker file: .homelab_repo_root (created at repo root and ignored by git).
# -----------------------------------------------------------------------------
echo "lib/common.sh"
# Guardrail: prevent double-sourcing.
if [[ -n "${_HOMELAB_COMMON_SOURCED:-}" ]]; then
  return 0
fi
readonly _HOMELAB_COMMON_SOURCED="1"

# Guardrail: safe defaults; do not force strict mode on consumers.
# If caller uses set -u, ensure our internal reads use ${var:-}.

# -----------------------------------------------------------------------------
# Logging and error helpers (aligns with menu/state if UI helpers exist)
# -----------------------------------------------------------------------------
_homelab_has_func() { declare -F "$1" >/dev/null 2>&1; }

homelab_info() {
  if _homelab_has_func ui_info; then ui_info "$*"; else echo "Info: $*"; fi
}

homelab_warn() {
  if _homelab_has_func ui_warn; then ui_warn "$*"; else echo "Warning: $*" >&2; fi
}

homelab_error() {
  if _homelab_has_func ui_error; then ui_error "$*"; else echo "Error: $*" >&2; fi
}

homelab_die() {
  homelab_error "$*"
  exit 1
}

# -----------------------------------------------------------------------------
# Repo root resolution
# -----------------------------------------------------------------------------
# Function: resolve_repo_root
# Guarantees:
#   - Exports REPO_ROOT as the same absolute path regardless of cwd depth.
#   - If git is present and we are in a git checkout, uses git rev-parse.
#   - Creates a marker file at the resolved root and adds it to .gitignore.
#   - If git is not present, resolves via marker walking up the directory tree.
#
# Returns:
#   0 on success, 1 on failure (caller can decide to exit)
#
resolve_repo_root() {
  local dir repo_root marker marker_path ignore_path
  marker=".homelab_repo_root"

  # Preferred path: Git knows best (handles worktrees/submodules properly).
  if command -v git >/dev/null 2>&1; then
    if repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
      REPO_ROOT="$repo_root"
      export REPO_ROOT
      _homelab_ensure_repo_marker "$REPO_ROOT" "$marker"
      return 0
    fi
  fi

  # Fallback path: walk up looking for marker
  dir="${PWD}"
  while :; do
    marker_path="${dir%/}/$marker"
    if [[ -f "$marker_path" ]]; then
      REPO_ROOT="$dir"
      export REPO_ROOT
      return 0
    fi
    [[ "$dir" == "/" ]] && break
    dir="${dir%/*}"
    [[ -z "$dir" ]] && dir="/"
  done

  homelab_error "not inside a recognised repository (no git root and no $marker found)"
  return 1
}

# Internal: ensure marker exists and is ignored by git.
_homelab_ensure_repo_marker() {
  local root="$1"
  local marker="$2"
  local marker_path ignore_path

  marker_path="${root%/}/$marker"
  ignore_path="${root%/}/.gitignore"

  if [[ ! -f "$marker_path" ]]; then
    : >"$marker_path" || {
      homelab_warn "unable to create repo marker at $marker_path"
      return 0
    }
  fi

  # If .gitignore exists, append if missing. If it doesn't exist, create it.
  if [[ -f "$ignore_path" ]]; then
    if ! grep -qxF "$marker" "$ignore_path" 2>/dev/null; then
      printf '%s\n' "$marker" >>"$ignore_path" || homelab_warn "unable to update $ignore_path"
    fi
  else
    printf '%s\n' "$marker" >"$ignore_path" || homelab_warn "unable to create $ignore_path"
  fi
}
