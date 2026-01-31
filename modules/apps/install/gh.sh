#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/install/gh.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps install module for gh (Github cli).
# Purpose: Package installation/removal module used by the apps pipeline.
# Usage:
#   ./modules/apps/install/gh.sh
# Prerequisites:
#   - Bash
#   - Debian/Ubuntu/Proxmox host with apt
# Notes:
#   - Idempotent and non-interactive.
#   - Logs to stdout/stderr only.
#   - Never prints secrets.
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if command -v gh >/dev/null 2>&1; then
  echo "[INFO] gh already installed"
  exit 0
fi

pkg_update
pkg_install gh
echo "[INFO] gh installed"
