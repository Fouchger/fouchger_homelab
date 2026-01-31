#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/install/yq.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Apps install module for yq.
# Purpose: Installs yq using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/install/yq.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Install yq

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if command -v yq >/dev/null 2>&1; then
  echo "[INFO] yq already installed"
  exit 0
fi

pkg_update
pkg_install yq
echo "[INFO] yq installed"
