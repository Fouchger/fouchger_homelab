#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/python3.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps uninstall module for python3.
# Purpose: Removes python3 python3-yaml using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/uninstall/python3.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Uninstall python3
#
# Purpose:
#   Remove python3 python3-yaml from the local host.
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

echo "[WARN] Removing packages can impact system stability. Proceeding: python3 python3-yaml" >&2

pkg_update
pkg_remove python3 python3-yaml
echo "[INFO] Removed: python3 python3-yaml"
