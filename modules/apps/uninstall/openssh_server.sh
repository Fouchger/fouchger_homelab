#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/openssh_server.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps uninstall module for openssh_server.
# Purpose: Removes openssh-server using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/uninstall/openssh_server.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Uninstall openssh_server
#
# Purpose:
#   Remove openssh-server from the local host.
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

echo "[WARN] Removing packages can impact system stability. Proceeding: openssh-server" >&2

pkg_update
pkg_remove openssh-server
echo "[INFO] Removed: openssh-server"
