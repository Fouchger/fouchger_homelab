#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/install/python3_venv.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps install module for python3_venv.
# Purpose: Package installation/removal module used by the apps pipeline.
# Usage:
#   ./modules/apps/install/python3_venv.sh
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

pkg_update
pkg_install python3-venv
echo "[INFO] python3_venv installed"
