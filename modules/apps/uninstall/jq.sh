#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/jq.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Apps uninstall module for jq.
# Purpose: Uninstalls jq using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/uninstall/jq.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Uninstall jq
#
# Purpose:
#   Uninstall jq from the local host.
#
# Contract:
#   - Must be idempotent: if not installed, exit 0.
#   - Must not prompt interactively.
#   - Must log via stdout/stderr.
#   - Must never print secrets.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "[INFO] jq not installed"
  exit 0
fi

pkg_remove jq
echo "[INFO] jq removed"
