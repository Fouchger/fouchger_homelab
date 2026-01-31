#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/logrotate.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps uninstall module for logrotate.
# Purpose: Removes logrotate using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/uninstall/logrotate.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Uninstall logrotate
#
# Purpose:
#   Remove logrotate from the local host.
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

echo "[WARN] Removing packages can impact system stability. Proceeding: logrotate" >&2

pkg_update
pkg_remove logrotate
echo "[INFO] Removed: logrotate"
