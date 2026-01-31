#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/ufw.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps uninstall module for ufw.
# Purpose: Removes ufw using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/uninstall/ufw.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Uninstall ufw
#
# Purpose:
#   Remove ufw from the local host.
#
# Contract:
#   - Must be non-interactive.
#   - Should be best-effort and idempotent.
#   - Must never print secrets.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

echo "[WARN] Removing packages can impact system stability. Proceeding: ufw" >&2

pkg_update
pkg_remove ufw
echo "[INFO] Removed: ufw"
