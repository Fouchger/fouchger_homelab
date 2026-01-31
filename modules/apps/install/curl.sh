#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/install/curl.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Apps install module for curl.
# Purpose: Installs curl using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/install/curl.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Install Curl
#
# Purpose:
#   Install Curl on the local host.
#
# Contract:
#   - Must be idempotent: if already installed, exit 0.
#   - Must not prompt interactively (UI prompts happen in commands/ via dialog).
#   - Must log via stdout/stderr (logger wrapper will capture output).
#   - Must never print secrets.
#
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if command -v curl >/dev/null 2>&1; then
  echo "[INFO] curl already installed"
  exit 0
fi

pkg_update
pkg_install curl
echo "[INFO] curl installed"
