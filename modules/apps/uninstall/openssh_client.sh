#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/openssh_client.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Apps uninstall module for openssh client.
# Purpose: Uninstalls openssh client using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/uninstall/openssh_client.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Uninstall OpenSSH client

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if ! command -v ssh >/dev/null 2>&1; then
  echo "[INFO] openssh-client not installed"
  exit 0
fi

pkg_remove openssh-client
echo "[INFO] openssh-client removed"
