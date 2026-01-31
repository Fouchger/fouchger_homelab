#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/kubectl.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps uninstall module for kubectl.
# Purpose: Removes kubectl from /usr/local/bin.
# Usage:
#   ./modules/apps/uninstall/kubectl.sh
# Notes:
# - This only removes the binary installed by this project.
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

sudo_cmd="$(pkg__sudo)"

if [[ -f /usr/local/bin/kubectl ]]; then
  ${sudo_cmd} rm -f /usr/local/bin/kubectl
  echo "[INFO] kubectl removed"
else
  echo "[INFO] kubectl not found at /usr/local/bin/kubectl"
fi
