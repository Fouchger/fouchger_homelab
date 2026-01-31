#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/common.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Shared, low-level helpers used across commands and libraries.
# Purpose: Keep small reusable patterns in one place (errors, checks, booleans).
# Usage:
#   source "${ROOT_DIR}/lib/common.sh"
#   require_cmd git
#   is_true "${DRY_RUN:-false}" && echo "Dry run"
# Prerequisites:
#   - bash >= 4
# Notes:
#   - Keep this file dependency-light to avoid circular sourcing.
#   - Do not print secrets from here. Prefer logger helpers when available.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

die() {
  local msg="${1:-"Unknown error"}"
  echo "🛑 $msg" >&2
  exit 1
}

require_cmd() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || die "require_cmd called without a command name"
  command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
}

is_true() {
  # Accepts: true/false, yes/no, 1/0 (case-insensitive).
  local v="${1:-false}"
  shopt -s nocasematch
  if [[ "$v" == "true" || "$v" == "yes" || "$v" == "1" ]]; then
    shopt -u nocasematch
    return 0
  fi
  shopt -u nocasematch
  return 1
}

safe_mkdir() {
  local dir="${1:-}"
  [[ -n "$dir" ]] || die "safe_mkdir called without a directory"
  mkdir -p "$dir"
}
