#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/core/make-executable.sh
# Created: 2026-01-20
# Description: Ensure all .sh scripts (and key entrypoints) in the current repo are executable.
# Usage:
#   bash scripts/core/make-executable.sh
# Notes:
#   - Runs in the current working directory by default; uses the git root if detected.
#   - Idempotent and safe to re-run.
# Maintainer: Gert
# -----------------------------------------------------------------------------
set -euo pipefail
set -o errtrace

# Resolve repo root (prefer git when available)
if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  BASE_DIR="$git_root"
else
  BASE_DIR="$(pwd)"
fi

echo "Working directory: $BASE_DIR"

# 1) Make all *.sh files executable (recursive)
echo "Making all *.sh files executable..."
while IFS= read -r -d '' file; do
  chmod +x "$file"
  echo "  chmod +x $file"
done < <(find "$BASE_DIR" -type f -name "*.sh" -print0)

# 2) Make key entrypoints executable (if present)
TARGETS=(
  "$BASE_DIR/bin/homelab"
)

echo "Making target Python scripts executable (if they exist)..."
for target in "${TARGETS[@]}"; do
  if [[ -f "$target" ]]; then
    chmod +x "$target"
    echo "  chmod +x $target"
  else
    echo "  Skipped (not found): $target"
  fi
done

echo "Done."