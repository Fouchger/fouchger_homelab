#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/install/cloud_init.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps install module for cloud_init.
# Purpose: Package installation/removal module used by the apps pipeline.
# Usage:
#   ./modules/apps/install/cloud_init.sh
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

if command -v cloud-init >/dev/null 2>&1; then
  echo "[INFO] cloud_init already installed"
  exit 0
fi

pkg_update
pkg_install cloud-init
echo "[INFO] cloud_init installed"
