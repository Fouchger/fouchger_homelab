#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/install/python3.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps install module for python3.
# Purpose: Package installation/removal module used by the apps pipeline.
# Usage:
#   ./modules/apps/install/python3.sh
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

if command -v python3 >/dev/null 2>&1; then
  echo "[INFO] python3 already installed"
  exit 0
fi

pkg_update
pkg_install python3 python3-yaml
echo "[INFO] python3 installed"
