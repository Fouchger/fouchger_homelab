#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/yq.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Apps uninstall module for yq.
# Purpose: Uninstalls yq using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/uninstall/yq.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Uninstall yq

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if ! command -v yq >/dev/null 2>&1; then
  echo "[INFO] yq not installed"
  exit 0
fi

pkg_remove yq
echo "[INFO] yq removed"
