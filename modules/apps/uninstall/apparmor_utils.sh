#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/apparmor_utils.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps uninstall module for apparmor_utils.
# Purpose: Removes apparmor-utils using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/uninstall/apparmor_utils.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Uninstall apparmor_utils
#
# Purpose:
#   Remove apparmor-utils from the local host.
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

echo "[WARN] Removing packages can impact system stability. Proceeding: apparmor-utils" >&2

pkg_update
pkg_remove apparmor-utils
echo "[INFO] Removed: apparmor-utils"
