#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/helm.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps uninstall module for helm.
# Purpose: Removes helm from /usr/local/bin.
# Usage:
#   ./modules/apps/uninstall/helm.sh
# Notes:
# - This only removes the binary installed by this project.
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

sudo_cmd="$(pkg__sudo)"

if [[ -f /usr/local/bin/helm ]]; then
  ${sudo_cmd} rm -f /usr/local/bin/helm
  echo "[INFO] helm removed"
else
  echo "[INFO] helm not found at /usr/local/bin/helm"
fi
