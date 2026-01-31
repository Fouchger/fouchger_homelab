#!/usr/bin/env bash
# ==============================================================================
# File: archieve/bin/lib/perms.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Archived legacy script retained for reference.
# Purpose: Retained for historical context; not part of current execution path.
# Usage:
#   ./archieve/bin/lib/perms.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# ==========================================================
# bin/lib/perms.sh
# Created: 29/01/2026
# Updated: 29/01/2026
# Purpose: Ensure required scripts are executable.
# Policy: Make all *.sh executable, plus additional configured paths.
# ==========================================================
set -euo pipefail

ensure_executables() {
  local root="$1"
  local extras_file="${root}/config/executables.list"

  # Make all shell scripts executable (repo-controlled)
  while IFS= read -r -d '' f; do
    chmod +x "$f" || true
  done < <(find "$root" -type f -name "*.sh" -print0)

  # Optional: make extra files executable (e.g., terraform wrapper, hooks)
  if [ -f "$extras_file" ]; then
    while IFS= read -r rel; do
      [ -z "$rel" ] && continue
      [[ "$rel" =~ ^# ]] && continue
      if [ -f "${root}/${rel}" ]; then
        chmod +x "${root}/${rel}" || true
      fi
    done < "$extras_file"
  fi
}
