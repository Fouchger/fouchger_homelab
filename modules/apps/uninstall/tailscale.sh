#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/tailscale.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Apps uninstall module for tailscale.
# Purpose: Uninstalls tailscale using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/uninstall/tailscale.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Uninstall Tailscale

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if ! command -v tailscale >/dev/null 2>&1; then
  echo "[INFO] tailscale not installed"
  exit 0
fi

pkg_remove tailscale
echo "[INFO] tailscale removed"
