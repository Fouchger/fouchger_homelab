#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/install/tailscale.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Apps install module for tailscale.
# Purpose: Installs tailscale using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/install/tailscale.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Install Tailscale

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if command -v tailscale >/dev/null 2>&1; then
  echo "[INFO] tailscale already installed"
  exit 0
fi

if ! apt-cache show tailscale >/dev/null 2>&1; then
  echo "[ERROR] tailscale package not available via configured apt repositories"
  echo "[INFO] Add the Tailscale apt repository for your distro, then re-run"
  exit 1
fi

pkg_update
pkg_install tailscale
echo "[INFO] tailscale installed"
